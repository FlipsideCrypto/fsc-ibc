{# Log configuration details #}
{{ log_model_details() }}

{# Set up dbt configuration #}
{{ config(
    materialized = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key = "block_timestamp_hour",
    cluster_by = ['block_timestamp_hour::DATE'],
    tags = ['silver_stats','curated','stats','daily_test','phase_4']
) }}

{# run incremental timestamp value first then use it as a static value #}
{% if execute %}

{% if is_incremental() %}
{% set query %}
SELECT
    MIN(DATE_TRUNC('hour', block_timestamp)) AS block_timestamp_hour
FROM
    {{ ref('core__fact_transactions') }}
WHERE
    modified_timestamp >= (
        SELECT
            MAX(modified_timestamp)
        FROM
            {{ this }}
    )
{% endset %}
    {% set min_block_timestamp_hour = run_query(query).columns [0].values() [0] %}
{% endif %}
{% endif %}

{# TODO: unique_from_count and total_fees are omitted because tx_from and fee are not present in core__fact_transactions. #}

{# Main query starts here #}
SELECT
    DATE_TRUNC('hour', block_timestamp) AS block_timestamp_hour,
    MIN(block_id) AS block_id_min,
    MAX(block_id) AS block_id_max,
    COUNT(DISTINCT block_id) AS block_count,
    COUNT(DISTINCT tx_id) AS transaction_count,
    COUNT(DISTINCT CASE WHEN tx_succeeded THEN tx_id END) AS transaction_count_success,
    COUNT(DISTINCT CASE WHEN NOT tx_succeeded THEN tx_id END) AS transaction_count_failed,
    SUM(gas_used) AS total_gas_used,
    MAX(modified_timestamp) AS _inserted_timestamp,
    {{ dbt_utils.generate_surrogate_key(['block_timestamp_hour']) }} AS core_metrics_hourly_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    {{ ref('core__fact_transactions') }}
WHERE
    DATE_TRUNC('hour', block_timestamp) < DATE_TRUNC('hour', CURRENT_TIMESTAMP)

{% if is_incremental() %}
AND DATE_TRUNC('hour', block_timestamp) >= '{{ min_block_timestamp_hour }}'
{% endif %}
GROUP BY 1
