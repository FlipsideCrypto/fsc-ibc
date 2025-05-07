{{ config (
    materialized = 'view',
    tags = ['bronze','core','phase_1']
) }}

{{ streamline_external_table_query(
    source_name = 'blocks',
    source_version = 'v2'
) }}