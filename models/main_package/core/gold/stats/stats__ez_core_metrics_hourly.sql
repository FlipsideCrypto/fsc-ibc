{# Get variables #}
{% set vars = return_vars() %}

{{ log_model_details() }}

{{ config(
    materialized = 'table',
    incremental_strategy = 'delete+insert',
    unique_key = "block_timestamp_hour",
    cluster_by = ['block_timestamp_hour::DATE'],
    meta ={ 'database_tags':{ 'table':{ 'PURPOSE': 'STATS, METRICS, CORE, HOURLY' } } },
    tags = ['gold','stats','curated','phase_4']
) }}

WITH txs AS (
    SELECT
        block_timestamp_hour,
        block_id_min,
        block_id_max,
        block_count,
        transaction_count,
        transaction_count_success,
        transaction_count_failed,
        total_gas_used,
        -- unique_from_count,  -- TODO: Add to silver_stats__core_metrics_hourly when available
        -- total_fees,         -- TODO: Add to silver_stats__core_metrics_hourly when available
        LAST_VALUE(
            p.close ignore nulls
        ) over (
            ORDER BY
                block_timestamp_hour rows unbounded preceding
        ) AS imputed_close,
        s.inserted_timestamp,
        s.modified_timestamp
    FROM
        {{ ref('silver_stats__core_metrics_hourly') }} s
        LEFT JOIN {{ ref('silver__hourly_prices_coin_gecko') }} p
        ON s.block_timestamp_hour = p.recorded_hour
        AND p.id = '{{ vars.GLOBAL_PROJECT_NAME }}'
)
SELECT
    block_timestamp_hour,
    block_id_min AS block_number_min,
    block_id_max AS block_number_max,
    block_count,
    transaction_count,
    transaction_count_success,
    transaction_count_failed,
    -- unique_from_count,  -- TODO: Add to silver_stats__core_metrics_hourly when available
    total_gas_used AS total_fees_native,  -- TODO: Replace with total_fees when available
    ROUND(
        total_gas_used * imputed_close,
        2
    ) AS total_fees_usd,
    {{ dbt_utils.generate_surrogate_key(['block_timestamp_hour']) }} AS ez_core_metrics_hourly_id,
    inserted_timestamp,
    modified_timestamp
FROM
    txs
WHERE
    block_timestamp_hour < DATE_TRUNC('hour', CURRENT_TIMESTAMP)
{% if is_incremental() %}
AND
    block_timestamp_hour >= COALESCE(
        DATEADD('hour', -4, (
            SELECT DATE_TRUNC('hour', MIN(block_timestamp_hour))
            FROM {{ ref('silver_stats__core_metrics_hourly') }}
            WHERE modified_timestamp >= (
                SELECT MAX(modified_timestamp) FROM {{ this }}
            )
        )),
        '2025-01-01 00:00:00'
    )
{% endif %} 