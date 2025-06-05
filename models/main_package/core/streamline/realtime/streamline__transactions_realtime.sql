{# Get variables #}
{% set vars = return_vars() %}

{# Log configuration details #}
{{ log_model_details() }}

{# Set up dbt configuration #}
{{ config (
    materialized = "view",
    tags = ['streamline','core','realtime','phase_1']
) }}

WITH blocks AS (

    SELECT
        A.block_id,
        A.block_timestamp,
        tx_count
    FROM
        {{ ref('streamline__blocks_complete') }} A
    WHERE
        tx_count > 0
),
numbers AS (
    -- Recursive CTE to generate numbers. We'll use the maximum txcount value to limit our recursion.
    SELECT
        1 AS n
    UNION ALL
    SELECT
        n + 1
    FROM
        numbers
    WHERE
        n < (
            SELECT
                CEIL(MAX(tx_count) / 100.0)
            FROM
                blocks)
        ),
        blocks_with_page_numbers AS (
            SELECT
                tt.block_id :: INT AS block_id,
                tt.block_timestamp,
                n.n AS page_number
            FROM
                blocks tt
                JOIN numbers n
                ON n.n <= CASE
                    WHEN tt.tx_count % 100 = 0 THEN tt.tx_count / 100
                    ELSE FLOOR(
                        tt.tx_count / 100
                    ) + 1
                END
            EXCEPT
            SELECT
                block_id,
                null as block_timestamp, -- placeholder for now...
                page_number
            FROM
                {{ ref('streamline__transactions_complete') }}
        )
    SELECT
        ROUND(
            block_id,
            -3
        ) :: INT AS partition_key,
        {{ target.database }}.live.udf_api(
            'POST',
            '{{ vars.GLOBAL_NODE_URL }}',
            OBJECT_CONSTRUCT(
                'Content-Type', 'application/json',
                'fsc-quantum-state', 'streamline'
            ),
            OBJECT_CONSTRUCT(
                'id', block_id,
                'jsonrpc', '2.0',
                'method', 'tx_search',
                'params', ARRAY_CONSTRUCT(
                    'tx.height=' || block_id :: STRING,
                    TRUE,
                    page_number :: STRING,
                    '100',
                    'asc'
                )
            ),
            '{{ vars.GLOBAL_NODE_VAULT_PATH }}'
        ) AS request,
        page_number,
        block_id AS block_id_requested,
        to_char(block_timestamp,'YYYY_MM_DD_HH_MI_SS_FF3') AS block_timestamp
    FROM
        blocks_with_page_numbers

LIMIT {{ vars.MAIN_SL_TRANSACTIONS_REALTIME_SQL_LIMIT }}

{# Streamline Function Call #}
{% if execute %}
    {% set params = {
        'external_table': 'transactions',
        'sql_limit': vars.MAIN_SL_TRANSACTIONS_REALTIME_SQL_LIMIT,
        'producer_batch_size': vars.MAIN_SL_TRANSACTIONS_REALTIME_PRODUCER_BATCH_SIZE,
        'worker_batch_size': vars.MAIN_SL_TRANSACTIONS_REALTIME_WORKER_BATCH_SIZE,
        'async_concurrent_requests': vars.MAIN_SL_TRANSACTIONS_REALTIME_ASYNC_CONCURRENT_REQUESTS,
        'sql_source' : this.identifier,
        'exploded_key': '["result.txs"]',
        "order_by_column": "block_id_requested"
    } %}

    {% set function_call_sql %}
    {{ fsc_utils.if_data_call_function_v2(
        func = 'streamline.udf_bulk_rest_api_v2',
        target = this.schema ~ '.' ~ this.identifier,
        params = params
    ) }}
    {% endset %}
    
    {% do run_query(function_call_sql) %}
    {{ log("Streamline function call: " ~ function_call_sql, info=true) }}
{% endif %}