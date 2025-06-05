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
        block_id
    FROM
        {{ ref('streamline__blocks') }}
    EXCEPT
    SELECT
        block_id
    FROM
        {{ ref('streamline__tx_count_complete') }}
),
{# retry AS (
SELECT
    NULL AS A.block_id
FROM
    {{ ref('streamline__complete_tx_counts') }} A
    JOIN {{ ref('silver__blockchain') }}
    b
    ON A.block_id = b.block_id
WHERE
    A.tx_count <> b.num_txs
),
#}
combo AS (
    SELECT
        block_id
    FROM
        blocks {# UNION
    SELECT
        block_id
    FROM
        retry #}
)
SELECT
    ROUND(block_id, -3) :: INT AS partition_key,
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
                'tx.height=' || block_id :: STRING, TRUE,
                '1',
                '1',
                'asc'
            )
        ),
        '{{ vars.GLOBAL_NODE_VAULT_PATH }}'
    ) AS request,
    block_id
FROM
    combo
ORDER BY
    block_id

{# Streamline Function Call #}
{% if execute %}
    {% set params = {
        'external_table': 'txcount',
        'sql_limit': vars.MAIN_SL_TX_COUNTS_REALTIME_SQL_LIMIT,
        'producer_batch_size': vars.MAIN_SL_TX_COUNTS_REALTIME_PRODUCER_BATCH_SIZE,
        'worker_batch_size': vars.MAIN_SL_TX_COUNTS_REALTIME_WORKER_BATCH_SIZE,
        'async_concurrent_requests': vars.MAIN_SL_TX_COUNTS_REALTIME_ASYNC_CONCURRENT_REQUESTS,
        'sql_source' : this.identifier
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