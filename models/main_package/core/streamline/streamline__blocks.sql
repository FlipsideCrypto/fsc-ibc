{{ config (
    materialized = "view",
    tags = ['streamline_view']
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
            COALESCE(
                block_id,
                0
            )
        FROM
            {{ ref('streamline__chainhead') }}
    )
