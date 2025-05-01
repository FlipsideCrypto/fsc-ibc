{# Get variables #}
{% set vars = return_vars() %}

-- depends_on: {{ ref('streamline__complete_tx_counts') }}

{{ config (
    materialized = 'view',
    tags = ['streamline','core','realtime','phase_1']
) }}

WITH blocks AS (

    SELECT
        block_number
    FROM
        {{ ref('streamline__blocks') }}
    EXCEPT
    SELECT
        block_number
    FROM
        {{ ref('streamline__tx_counts_complete') }}
),
{# retry AS (
SELECT
    NULL AS A.block_number
FROM
    {{ ref('streamline__complete_tx_counts') }} A
    JOIN {{ ref('silver__blockchain') }}
    b
    ON A.block_number = b.block_id
WHERE
    A.tx_count <> b.num_txs
),
#}
combo AS (
    SELECT
        block_number
    FROM
        blocks {# UNION
    SELECT
        block_number
    FROM
        retry #}
)
SELECT
    ROUND(block_number, -3) :: INT AS partition_key,
    {{ target.database }}.live.udf_api(
        'POST',
        '{{ vars.GLOBAL_NODE_URL }}',
        OBJECT_CONSTRUCT(
            'Content-Type', 'application/json',
            'fsc-quantum-state', 'streamline'
        ),
        OBJECT_CONSTRUCT(
            'id', block_number,
            'jsonrpc', '2.0',
            'method', 'tx_search',
            'params', ARRAY_CONSTRUCT(
                'tx.height=' || block_number :: STRING, TRUE,
                '1',
                '1',
                'asc'
            )
        ),
        '{{ vars.GLOBAL_NODE_VAULT_PATH }}'
    ) AS request,
    block_number
FROM
    combo
ORDER BY
    block_number

{# Streamline Function Call #}
{% if execute %}
    {% set params = {
        'external_table': 'txcount',
        'sql_limit': vars.MAIN_SL_TX_COUNTS_REALTIME_SQL_LIMIT,
        'producer_batch_size': vars.MAIN_SL_TX_COUNTS_REALTIME_PRODUCER_BATCH_SIZE,
        'worker_batch_size': vars.MAIN_SL_TX_COUNTS_REALTIME_WORKER_BATCH_SIZE,
        'async_concurrent_requests': vars.MAIN_SL_TX_COUNTS_REALTIME_ASYNC_CONCURRENT_REQUESTS,
        'sql_source' :"{{this.identifier}}"
    } %}

    {% set function_call_sql %}
    {{ fsc_utils.if_data_call_function_v2(
        func = 'streamline.udf_bulk_rest_api_v2',
        target = '{{this.schema}}.{{this.identifier}}',
        params = params
    ) }}
    {% endset %}
    
    {% do run_query(function_call_sql) %}
    {{ log("Streamline function call: " ~ function_call_sql, info=true) }}
{% endif %}