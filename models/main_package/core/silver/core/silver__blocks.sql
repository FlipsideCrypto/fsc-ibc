{# Get variables #}
{% set vars = return_vars() %}
-- depends_on: {{ ref('bronze__blocks') }}
{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'blocks_id',
    cluster_by = ['modified_timestamp::DATE'],
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['silver','core','phase_2']
) }}

WITH bronze_blocks AS (

    SELECT
        '{{ vars.GLOBAL_PROJECT_NAME }}' AS blockchain,
        VALUE :BLOCK_ID :: INT AS block_id,
        COALESCE(
            DATA :result :block :header :time :: TIMESTAMP,
            DATA :block :header :time :: TIMESTAMP,
            DATA :result :block :header :timestamp :: TIMESTAMP,
            DATA :block :header :timestamp :: TIMESTAMP
        ) AS block_timestamp,
        COALESCE(
            DATA :result :block :header :chain_id :: STRING,
            DATA :block :header :chain_id :: STRING
        ) AS chain_id,
        COALESCE(
            ARRAY_SIZE(
                DATA :result :block :data :txs
            ) :: NUMBER,
            ARRAY_SIZE(
                DATA :block :data :txs
            ) :: NUMBER
        ) AS tx_count,
        COALESCE(
            DATA :result :block :header :proposer_address :: STRING,
            DATA :block :header :proposer_address :: STRING
        ) AS proposer_address,
        COALESCE(
            DATA :result :block :header :validators_hash :: STRING,
            DATA :block :header :validators_hash :: STRING
        ) AS validator_hash,
        COALESCE(
            DATA :result :block :header,
            DATA :block :header
        ) AS header,
        inserted_timestamp
    FROM

{% if is_incremental() %}
{{ ref('bronze__blocks') }}
{% else %}
    {{ ref('bronze__blocks_fr') }}
{% endif %}
WHERE
    VALUE :data :error IS NULL
    AND DATA :error IS NULL

{% if is_incremental() %}
AND inserted_timestamp >= (
    SELECT
        MAX(inserted_timestamp)
    FROM
        {{ this }}
)
{% endif %}
)
SELECT
    blockchain,
    block_id,
    block_timestamp,
    chain_id,
    tx_count,
    proposer_address,
    validator_hash,
    header,
    {{ dbt_utils.generate_surrogate_key(['chain_id', 'block_id']) }} AS blocks_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    bronze_blocks 
WHERE
    block_id is not null
QUALIFY ROW_NUMBER() OVER (
        PARTITION BY chain_id,
        block_id
        ORDER BY
            inserted_timestamp DESC
    ) = 1
