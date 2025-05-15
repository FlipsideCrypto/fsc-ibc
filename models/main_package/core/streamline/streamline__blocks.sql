{# Get variables #}
{% set vars = return_vars() %}

{# Log configuration details #}
{{ log_model_details() }}

{{ config (
    materialized = "view",
    tags = ['streamline','core','chainhead','phase_1']
) }}

SELECT
    _id AS block_id
FROM
    {{ source(
        'crosschain_silver',
        'number_sequence'
    ) }}
WHERE
    _id <= (
        SELECT
            MAX(block_number)
        FROM
            {{ ref('streamline__chainhead') }}
    )
