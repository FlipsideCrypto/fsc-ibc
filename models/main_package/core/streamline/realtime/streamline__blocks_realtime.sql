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
        {{ ref('streamline__blocks_complete') }}
)
SELECT
    ROUND(block_id, -4) :: INT AS partition_key,
    block_id,
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
            'method', 'block',
            'params', ARRAY_CONSTRUCT(block_id :: STRING)
        ),
        '{{ vars.GLOBAL_NODE_VAULT_PATH }}'
    ) AS request
FROM
    blocks    

LIMIT {{ vars.MAIN_SL_BLOCKS_REALTIME_SQL_LIMIT }}

{# Streamline Function Call #}
{% if execute %}
    {% set params = {
        'external_table': 'blocks',
        'sql_limit': vars.MAIN_SL_BLOCKS_REALTIME_SQL_LIMIT,
        'producer_batch_size': vars.MAIN_SL_BLOCKS_REALTIME_PRODUCER_BATCH_SIZE,
        'worker_batch_size': vars.MAIN_SL_BLOCKS_REALTIME_WORKER_BATCH_SIZE,
        'async_concurrent_requests': vars.MAIN_SL_BLOCKS_REALTIME_ASYNC_CONCURRENT_REQUESTS,
        'sql_source' : this.identifier,
        "order_by_column": "block_id"
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
