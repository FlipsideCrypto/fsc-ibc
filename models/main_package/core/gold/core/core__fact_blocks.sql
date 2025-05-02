{# Get variables #}
{% set vars = return_vars() %}

{# Set fact_blocks specific variables #}
{% set rpc_vars = set_dynamic_fields('fact_blocks') %}

{{ config(
    materialized = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key = 'blocks_id',
    cluster_by = ['block_timestamp::DATE'],
    post_hook = "ALTER TABLE {{ this }} ADD SEARCH OPTIMIZATION on equality(block_id)",
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['gold', 'core', 'phase_2']
) }}

SELECT
    blockchain,
    block_id,
    block_timestamp,
    chain_id,
    tx_count,
    proposer_address,
    validator_hash,
    {{ dbt_utils.generate_surrogate_key(['block_id']) }} AS fact_blocks_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    {{ ref('silver__blocks') }}
{% if is_incremental() %}
WHERE
    modified_timestamp :: DATE >= (
        SELECT
            MAX(modified_timestamp)
        FROM
            {{ this }}
    )
{% endif %}