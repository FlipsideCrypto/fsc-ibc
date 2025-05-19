{# Get variables #}
{% set vars = return_vars() %}

{# Set fact_transactions_logs specific variables #}
{% set rpc_vars = set_dynamic_fields('fact_transactions_logs') %}

{{ config(
    materialized = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key = 'transactions_logs_id',
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
    tx_code,
    codespace,
    tx_log,
    transactions_logs_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    {{ ref('silver__transactions_logs') }}
{% if is_incremental() %}
WHERE
    modified_timestamp :: DATE >= (
        SELECT
            MAX(modified_timestamp)
        FROM
            {{ this }}
    )
{% endif %}
