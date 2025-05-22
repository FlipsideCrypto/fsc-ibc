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
        block_id,
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
            ARRAY_SIZE(DATA :result :block :data :txs) :: NUMBER,
            ARRAY_SIZE(DATA :block :data :txs) :: NUMBER
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
        _inserted_timestamp
    FROM
        {{ ref('bronze__blocks') }}
    WHERE
        VALUE :data :error IS NULL
        AND DATA :error IS NULL
        AND DATA :result :begin_block_events IS NULL
    {% if is_incremental() %}
    AND _inserted_timestamp :: DATE >= (
        SELECT
            MAX(_inserted_timestamp) :: DATE - 2
        FROM
            {{ this }}
    )
    {% endif %}
)
SELECT
    block_id,
    block_timestamp,
    chain_id,
    tx_count,
    proposer_address,
    validator_hash,
    header,
    _inserted_timestamp,
    {{ dbt_utils.generate_surrogate_key(['chain_id', 'block_id']) }} AS blocks_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    bronze_blocks
QUALIFY ROW_NUMBER() over (
    PARTITION BY chain_id, block_id 
    ORDER BY _inserted_timestamp DESC
) = 1
