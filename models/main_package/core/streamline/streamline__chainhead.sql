{# Get variables #}
{% set vars = return_vars() %}

{# Log configuration details #}
{{ log_model_details() }}

{{ config (
    materialized = 'table',
    tags = ['streamline','core','chainhead','phase_1']
) }}

SELECT
    {{ target.database }}.live.udf_api(
        'POST',
        '{Service}/{Authentication}',
        OBJECT_CONSTRUCT(
            'Content-Type',
            'application/json',
            'fsc-quantum-state',
            'livequery'
        ),
        OBJECT_CONSTRUCT(
            'id',
            0,
            'jsonrpc',
            '2.0',
            'method',
            'status',
            'params',
            []
        ),
        '{{ vars.GLOBAL_NODE_VAULT_PATH }}'
    ) :data :result :sync_info :latest_block_height :: INT AS block_id