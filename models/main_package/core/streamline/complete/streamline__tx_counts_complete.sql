{# Get variables #}
{% set vars = return_vars() %}

-- depends_on: {{ ref('bronze__tx_counts') }}

{{ config (
    materialized = "incremental",
    incremental_strategy = 'merge',
    unique_key = "block_id",
    cluster_by = "ROUND(block_id, -3)",
    merge_exclude_columns = ["inserted_timestamp"],
    post_hook = "ALTER TABLE {{ this }} ADD SEARCH OPTIMIZATION on equality(block_id)"
) }}

SELECT
    VALUE :block_id :: INT AS block_id,
    DATA :result :total_count :: INT AS tx_count,
    {{ dbt_utils.generate_surrogate_key(
        ['block_id']
    ) }} AS complete_tx_counts_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    file_name,
    '{{ invocation_id }}' AS _invocation_id
FROM

{% if is_incremental() %}
{{ ref('bronze__tx_counts') }}
WHERE
    inserted_timestamp >= (
        SELECT
            MAX(modified_timestamp) modified_timestamp
        FROM
            {{ this }}
    )
    AND block_id NOT IN (21208991)
{% else %}
    {{ ref('bronze__tx_counts_fr') }}
{% endif %}

qualify(ROW_NUMBER() over (PARTITION BY block_id
ORDER BY
    inserted_timestamp DESC)) = 1
