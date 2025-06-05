{# Get variables #}
{% set vars = return_vars() %}

{# Set fact_transactions specific variables #}
{#{% set rpc_vars = set_dynamic_fields('fact_transactions') %}#}

{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'transactions_id',
    cluster_by = ['block_timestamp::DATE'],
    post_hook = "ALTER TABLE {{ this }} ADD SEARCH OPTIMIZATION on equality(block_id, tx_id)",
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['gold', 'core', 'phase_2']
) }}

SELECT
    block_id,
    block_timestamp,
    tx_id,
    tx_succeeded,
    CONCAT(
        msg_group,
        ':',
        msg_sub_group
    ) AS msg_group,
    msg_type,
    msg_index,
    msg,
    {{ dbt_utils.generate_surrogate_key(['tx_id', 'msg_index']) }} AS fact_msgs_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    {{ ref('silver__msgs') }}
{% if is_incremental() %}
WHERE
    modified_timestamp :: DATE >= (
        SELECT
            MAX(modified_timestamp)
        FROM
            {{ this }}
    )
{% endif %}