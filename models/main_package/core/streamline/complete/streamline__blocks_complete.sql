{# Get variables #}
{% set vars = return_vars() %}

-- depends_on: {{ ref('bronze__blocks') }}
{{ config (
    materialized = "incremental",
    incremental_strategy = 'merge',
    unique_key = "block_id",
    cluster_by = "ROUND(block_id, -3)",
    merge_exclude_columns = ["inserted_timestamp"],
    post_hook = "ALTER TABLE {{ this }} ADD SEARCH OPTIMIZATION on equality(block_id)"
) }}

SELECT
    DATA :result :block :header :height :: INT AS block_id,
    {{ dbt_utils.generate_surrogate_key(
        ['block_id']
    ) }} AS complete_blocks_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    file_name,
    '{{ invocation_id }}' AS _invocation_id
FROM

{% if is_incremental() %}
{{ ref('bronze__blocks') }}
WHERE
    inserted_timestamp >= (
        SELECT
            MAX(modified_timestamp) modified_timestamp
        FROM
            {{ this }}
    )
{% else %}
    {{ ref('bronze__blocks_fr') }}
{% endif %}

qualify(ROW_NUMBER() over (PARTITION BY block_id
ORDER BY
    inserted_timestamp DESC)) = 1
