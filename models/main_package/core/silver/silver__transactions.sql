{# Get variables #}
{% set vars = return_vars() %}

-- depends_on: {{ ref('bronze__streamline_transactions') }}
-- depends_on: {{ ref('bronze__streamline_transactions_fr') }}

{{ config (
    materialized = "incremental",
    incremental_strategy = 'delete+insert',
    unique_key = 'transactions_id',
    cluster_by = ['modified_timestamp::DATE','partition_key'],
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['silver', 'core', 'phase_2']
) }}

WITH bronze_transactions AS (
    SELECT
        block_id,
        COALESCE(
            DATA :hash, 
            f.value :hash
        ) :: STRING AS tx_id,
        COALESCE(
            DATA :index, 
            f.index
        ) AS tx_index,
        COALESCE(
            DATA :tx_result :codespace,
            f.value :tx_result :codespace
        ) :: STRING AS codespace,
        COALESCE(
            DATA :tx_result :gas_used,
            f.value :tx_result :gas_used
        ) :: NUMBER AS gas_used,
        COALESCE(
            DATA :tx_result :gas_wanted,
            f.value :tx_result :gas_wanted
        ) :: NUMBER AS gas_wanted,
        COALESCE(
            DATA :tx_result :code,
            f.value :tx_result :code
        ) :: INT AS tx_code,
        COALESCE(
            TRY_PARSE_JSON(
                COALESCE(
                    DATA :tx_result :log,
                    f.value :tx_result :log
                )
            ),
            COALESCE(
                DATA :tx_result :log,
                f.value :tx_result :log
            )
        ) AS tx_log,
        CASE
            WHEN f.value IS NOT NULL THEN f.value
            ELSE DATA
        END AS DATA,
        partition_key,
        COALESCE(
            transactions.value :block_id_REQUESTED,
            REPLACE(
                metadata :request :params [0],
                'tx.height='
            )
        ) AS block_id_requested,
        inserted_timestamp AS _inserted_timestamp
    FROM
        {% if is_incremental() %}
            {{ ref('bronze__streamline_transactions') }}
        {% else %}
            {{ ref('bronze__streamline_transactions_fr') }}
        {% endif %}
        AS transactions
    JOIN LATERAL FLATTEN(
        DATA :result :txs,
        outer => TRUE
    ) AS f
    WHERE
        {% if is_incremental() %}
        inserted_timestamp >= (
            SELECT
                MAX(_inserted_timestamp)
            FROM
                {{ this }}
        )
        {% endif %}
)
SELECT
    block_id,
    block_timestamp,
    codespace,
    tx_id,
    tx_index,
    tx_log,
    tx_succeeded,
    {# tx_from, #}
    {# fee, #}
    {# fee_denom, #}
    gas_used,
    gas_wanted,
    tx_code,
    DATA,
    partition_key,
    block_id_requested,
    _inserted_timestamp,
    {{ dbt_utils.generate_surrogate_key(
        ['block_id_requested', 'tx_id']
    ) }} AS transactions_id,
    SYSDATE() AS inserted_timestamp,
    SYSDATE() AS modified_timestamp,
    '{{ invocation_id }}' AS _invocation_id
FROM
    bronze_transactions
QUALIFY(ROW_NUMBER() over (
    PARTITION BY block_id_requested, tx_id
    ORDER BY _inserted_timestamp DESC)
) = 1 