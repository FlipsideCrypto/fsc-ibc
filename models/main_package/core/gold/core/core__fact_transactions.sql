{# Get variables #}
{% set vars = return_vars() %}

{# Set fact_transactions specific variables #}
{#{% set rpc_vars = set_dynamic_fields('fact_transactions') %}#}

{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'transactions_id',
    cluster_by = ['block_timestamp::DATE'],
    incremental_predicates = [fsc_ibc.standard_predicate()],
    post_hook = "ALTER TABLE {{ this }} ADD SEARCH OPTIMIZATION on equality(block_id, tx_id)",
    tags = ['gold', 'core', 'phase_2']
) }}

SELECT
    block_id,
    block_timestamp,
    codespace,
    tx_id,
    {# tx_from, #}
    tx_succeeded,
    tx_code,
    tx_log,
    {# fee, #}
    {# fee_denom, #}
    gas_used,
    gas_wanted,
    {{ dbt_utils.generate_surrogate_key(['tx_id']) }} AS fact_transactions_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    {{ ref('silver__transactions') }}
{% if is_incremental() %}
WHERE
    modified_timestamp :: DATE >= (
        SELECT
            MAX(modified_timestamp)
        FROM
            {{ this }}
    )
{% endif %}