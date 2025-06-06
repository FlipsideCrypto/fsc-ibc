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
        MIN(block_number) AS min_block,
        MAX(block_number) AS max_block,
        MIN(block_timestamp) AS min_block_timestamp,
        MAX(block_timestamp) AS max_block_timestamp,
        COUNT(1) AS blocks_tested
    FROM
        {{ ref('core__fact_blocks') }}
    WHERE
        block_timestamp <= DATEADD('hour', -12, CURRENT_TIMESTAMP())
    {% if is_incremental() %}
    AND (
        block_number >= (
            SELECT MIN(block_number) FROM (
                SELECT MIN(block_number) AS block_number
                FROM {{ ref('core__fact_blocks') }}
                WHERE block_timestamp BETWEEN DATEADD('hour', -96, CURRENT_TIMESTAMP())
                    AND DATEADD('hour', -95, CURRENT_TIMESTAMP())
                UNION
                SELECT MIN(VALUE) - 1 AS block_number
                FROM (
                    SELECT blocks_impacted_array
                    FROM {{ this }}
                    QUALIFY ROW_NUMBER() OVER (ORDER BY test_timestamp DESC) = 1
                ),
                LATERAL FLATTEN(input => blocks_impacted_array)
            )
        )
        {% if vars.MAIN_OBSERV_FULL_TEST_ENABLED %}
        OR block_number >= 0
        {% endif %}
    )
    {% endif %}
),
block_range AS (
    SELECT _id AS block_number
    FROM {{ source('crosschain_silver', 'number_sequence') }}
    WHERE _id BETWEEN (
        SELECT min_block FROM summary_stats
    ) AND (
        SELECT max_block FROM summary_stats
    )
),
blocks AS (
    SELECT
        l.block_number,
        block_timestamp,
        LAG(l.block_number, 1) OVER (ORDER BY l.block_number ASC) AS prev_block_number
    FROM {{ ref('core__fact_blocks') }} l
    INNER JOIN block_range b ON l.block_number = b.block_number
    AND l.block_number >= (
        SELECT MIN(block_number) FROM block_range
    )
),
block_gen AS (
    SELECT _id AS block_number
    FROM {{ source('crosschain_silver', 'number_sequence') }}
    WHERE _id BETWEEN (
        SELECT MIN(block_number) FROM blocks
    ) AND (
        SELECT MAX(block_number) FROM blocks
    )
)
SELECT
    'blocks' AS test_name,
    MIN(b.block_number) AS min_block,
    MAX(b.block_number) AS max_block,
    MIN(b.block_timestamp) AS min_block_timestamp,
    MAX(b.block_timestamp) AS max_block_timestamp,
    COUNT(1) AS blocks_tested,
    COUNT(CASE WHEN C.block_number IS NOT NULL THEN A.block_number END) AS blocks_impacted_count,
    ARRAY_AGG(CASE WHEN C.block_number IS NOT NULL THEN A.block_number END) WITHIN GROUP (ORDER BY A.block_number) AS blocks_impacted_array,
    CURRENT_TIMESTAMP() AS test_timestamp,
    CURRENT_TIMESTAMP() AS modified_timestamp
FROM block_gen A
LEFT JOIN blocks b ON A.block_number = b.block_number
LEFT JOIN blocks C ON A.block_number > C.prev_block_number
    AND A.block_number < C.block_number
    AND C.block_number - C.prev_block_number <> 1
WHERE COALESCE(b.block_number, C.block_number) IS NOT NULL
