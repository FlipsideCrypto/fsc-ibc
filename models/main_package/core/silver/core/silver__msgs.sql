{# Get variables #}
{% set vars = return_vars() %}

-- depends_on: {{ ref('silver__transactions') }}

{{ config (
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'msgs_id',
    cluster_by = ['modified_timestamp::DATE'],
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['silver', 'core', 'phase_2']
) }}

WITH bronze_msgs AS (

  SELECT
    transactions.block_id,
    transactions.block_timestamp,
    transactions.tx_id,
    transactions.gas_used,
    transactions.gas_wanted,
    transactions.tx_succeeded,
    f.value AS msg,
    f.index :: INT AS msg_index,
    msg :type :: STRING AS msg_type,
    IFF(
        CASE
            WHEN TRY_BASE64_DECODE_STRING(msg :attributes [0] :key) IS NULL
            THEN msg :attributes [0] :key
            ELSE TRY_BASE64_DECODE_STRING(msg :attributes [0] :key)
        END :: STRING = 'action',
        TRUE,
        FALSE
    ) AS is_action,
    NULLIF(
        (CONDITIONAL_TRUE_EVENT(is_action) OVER (
            PARTITION BY tx_id
            ORDER BY msg_index ASC
        ) - 1),
        -1
    ) AS msg_group,
    IFF(
        CASE
            WHEN TRY_BASE64_DECODE_STRING(msg :attributes [0] :key) IS NULL
            THEN msg :attributes [0] :key
            ELSE TRY_BASE64_DECODE_STRING(msg :attributes [0] :key)
        END :: STRING = 'module',
        TRUE,
        FALSE
    ) AS is_module,
    CASE
        WHEN TRY_BASE64_DECODE_STRING(msg :attributes [0] :key) IS NULL
        THEN msg :attributes [0] :key
        ELSE TRY_BASE64_DECODE_STRING(msg :attributes [0] :key)
    END :: STRING AS attribute_key,
    CASE
        WHEN TRY_BASE64_DECODE_STRING(msg :attributes [0] :key) IS NULL
        THEN msg :attributes [0] :key
        ELSE TRY_BASE64_DECODE_STRING(msg :attributes [0] :value)
    END AS attribute_value,
    transactions._inserted_timestamp
  FROM
    {{ ref('silver__transactions') }} transactions
  JOIN LATERAL FLATTEN(input => transactions.msgs) f
    {% if is_incremental() %}
    WHERE
    _inserted_timestamp :: DATE >= (
        SELECT
            MAX(_inserted_timestamp) :: DATE - 2
        FROM
            {{ this }}
    )
    {% endif %}
),
exec_actions AS (
    SELECT
        DISTINCT tx_id,
        msg_group
    FROM
        bronze_msgs
    WHERE
        msg_type = 'message'
        AND attribute_key = 'action'
        AND LOWER(attribute_value) LIKE '%exec%'
),
GROUPING AS (
    SELECT
        bronze_msgs.tx_id,
        bronze_msgs.msg_index,
        RANK() OVER (
            PARTITION BY bronze_msgs.tx_id,
            bronze_msgs.msg_group
            ORDER BY bronze_msgs.msg_index
        ) -1 AS msg_sub_group
    FROM
        bronze_msgs
    INNER JOIN 
        exec_actions e
        ON bronze_msgs.tx_id = e.tx_id
        AND bronze_msgs.msg_group = e.msg_group
    WHERE
        bronze_msgs.is_module = 'TRUE'
        AND bronze_msgs.msg_type = 'message'
),
msgs AS (
    SELECT
        block_id,
        block_timestamp,
        bronze_msgs.tx_id,
        tx_succeeded,
        msg_group,
        CASE
            WHEN msg_group IS NULL THEN NULL
            ELSE COALESCE(
                LAST_VALUE(b.msg_sub_group IGNORE NULLS) OVER (
                    PARTITION BY bronze_msgs.tx_id, msg_group
                    ORDER BY bronze_msgs.msg_index DESC
                    ROWS UNBOUNDED PRECEDING
                ),
                0
            )
        END AS msg_sub_group,
        bronze_msgs.msg_index,
        msg_type,
        msg,
        bronze_msgs._inserted_timestamp
    FROM
        bronze_msgs
    LEFT JOIN GROUPING b
        ON bronze_msgs.tx_id = b.tx_id
        AND bronze_msgs.msg_index = b.msg_index
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
    msg :: OBJECT AS msg,
    {{ dbt_utils.generate_surrogate_key(
        ['tx_id','msg_index']
    ) }} AS msgs_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    _inserted_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    msgs
