{# Get variables #}
{% set vars = return_vars() %}

-- depends_on: {{ ref('silver__msgs') }}

{{ config (
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'msg_attributes_id',
    cluster_by = ['modified_timestamp::DATE'],
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['silver', 'core', 'phase_2']
) }}

WITH silver_msgs AS (
    SELECT
        block_id,
        block_timestamp,
        tx_id,
        tx_succeeded,
        msg_group,
        msg_sub_group,
        msg_index,
        msg_type,
        f.index AS attribute_index,
        CASE
            WHEN TRY_BASE64_DECODE_STRING(f.value :key) IS NULL
            THEN f.value :key
            ELSE TRY_BASE64_DECODE_STRING(f.value :key)
        END AS attribute_key,
        CASE
            WHEN TRY_BASE64_DECODE_STRING(f.value :key) IS NULL
            THEN f.value :value
            ELSE TRY_BASE64_DECODE_STRING(f.value :value)
        END AS attribute_value,
        msgs._inserted_timestamp
    FROM
        {{ ref('silver__msgs') }} AS msgs
    LATERAL FLATTEN(
        input => msgs.msg,
        path => 'attributes'
    ) AS f
    {% if is_incremental() %}
    WHERE
        _inserted_timestamp :: DATE >= (
            SELECT
                MAX(_inserted_timestamp) :: DATE - 2
            FROM
                {{ this }}
        )
    {% endif %}
)
SELECT
    block_id,
    block_timestamp,
    tx_id,
    tx_succeeded,
    msg_group,
    msg_sub_group,
    msg_index,
    msg_type,
    attribute_index,
    attribute_key,
    attribute_value,
    {{ dbt_utils.generate_surrogate_key(
        ['tx_id','msg_index','attribute_index']
    ) }} AS msg_attributes_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    _inserted_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    silver_msgs
