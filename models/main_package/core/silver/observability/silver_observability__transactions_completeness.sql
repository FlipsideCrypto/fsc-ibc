{% set vars = return_vars() %}
{{ log_model_details() }}

{{ config(
    materialized = 'incremental',
    unique_key = 'test_timestamp',
    full_refresh = vars.GLOBAL_SILVER_FR_ENABLED,
    tags = ['silver','observability','phase_3']
) }}

WITH summary_stats AS (
    SELECT
        MIN(block_id) AS min_block_id,
        MAX(block_id) AS max_block_id,
        MIN(block_timestamp) AS min_block_timestamp,
        MAX(block_timestamp) AS max_block_timestamp,
        COUNT(1) AS blocks_tested
    FROM
        {{ ref('core__fact_blocks') }}
    WHERE
        block_timestamp <= DATEADD('hour', -12, CURRENT_TIMESTAMP())
    {% if is_incremental() %}
    AND (
        block_id >= (
            SELECT MIN(block_id) FROM (
                SELECT MIN(block_id) AS block_id
                FROM {{ ref('core__fact_blocks') }}
                WHERE block_timestamp BETWEEN DATEADD('hour', -96, CURRENT_TIMESTAMP())
                    AND DATEADD('hour', -95, CURRENT_TIMESTAMP())
                UNION
                SELECT MIN(VALUE) - 1 AS block_id
                FROM (
                    SELECT blocks_impacted_array
                    FROM {{ this }}
                    QUALIFY ROW_NUMBER() OVER (ORDER BY test_timestamp DESC) = 1
                ),
                LATERAL FLATTEN(input => blocks_impacted_array)
            )
        )
        {% if vars.MAIN_OBSERV_FULL_TEST_ENABLED %}
        OR block_id >= 0
        {% endif %}
    )
    {% endif %}
),
base_blocks AS (
    SELECT
        block_id,
        block_timestamp,
        tx_count AS transaction_count
    FROM
        {{ ref('core__fact_blocks') }}
    WHERE
        block_timestamp <= (
            SELECT max_block_timestamp FROM summary_stats
        )
),
actual_tx_counts AS (
    SELECT
        block_id,
        COUNT(1) AS transaction_count
    FROM
        {{ ref('core__fact_transactions') }}
    WHERE
        block_id IS NOT NULL
    GROUP BY block_id
),
potential_missing_txs AS (
    SELECT
        e.block_id
    FROM
        base_blocks e
        LEFT OUTER JOIN actual_tx_counts a
        ON e.block_id = a.block_id
    WHERE
        COALESCE(a.transaction_count, 0) <> e.transaction_count
),
impacted_blocks AS (
    SELECT
        COUNT(1) AS blocks_impacted_count,
        ARRAY_AGG(block_id) WITHIN GROUP (ORDER BY block_id) AS blocks_impacted_array
    FROM potential_missing_txs
)
SELECT
    'transactions' AS test_name,
    min_block_id AS min_block,
    max_block_id AS max_block,
    min_block_timestamp,
    max_block_timestamp,
    blocks_tested,
    blocks_impacted_count,
    blocks_impacted_array,
    SYSDATE() AS test_timestamp,
    SYSDATE() AS modified_timestamp
FROM
    summary_stats
    JOIN impacted_blocks
    ON 1 = 1
