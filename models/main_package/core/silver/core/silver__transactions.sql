{# Get variables #}
{% set vars = return_vars() %}
-- depends_on: {{ ref('bronze__transactions') }}
-- depends_on: {{ ref('bronze__transactions_fr') }}
{{ config (
    materialized = "incremental",
    incremental_strategy = 'merge',
    unique_key = 'transactions_id',
    cluster_by = ['modified_timestamp::DATE','partition_key'],
    incremental_predicates = [fsc_ibc.standard_predicate()],
    tags = ['silver', 'core', 'phase_2']
) }}

WITH bronze_transactions AS (

    SELECT
        block_id,
        TO_TIMESTAMP(
            DATA :BLOCK_TIMESTAMP 'YYYY_MM_DD_HH_MI_SS_FF3'
        ) AS block_timestamp,
        DATA :hash :: STRING AS tx_id,
        DATA :index AS tx_index,
        DATA :tx_result :codespace :: STRING AS codespace,
        DATA :tx_result :gas_used :: NUMBER AS gas_used,
        DATA :tx_result :gas_wanted :: NUMBER AS gas_wanted,
        CASE
            WHEN DATA :tx_result :code :: NUMBER = 0 THEN TRUE
            ELSE FALSE
        END AS tx_succeeded,
        DATA :tx_result :code :: INT AS tx_code,
        COALESCE(
            TRY_PARSE_JSON(
                DATA :tx_result :log
            ),
            DATA :tx_result :log
        ) AS tx_log,
        DATA,
        partition_key,
        DATA :BLOCK_ID_REQUESTED AS block_id_requested,
        inserted_timestamp AS _inserted_timestamp,
        {{ dbt_utils.generate_surrogate_key(
            ['block_id_requested', 'tx_id']
        ) }} AS transactions_id,
        SYSDATE() AS inserted_timestamp,
        SYSDATE() AS modified_timestamp,
        '{{ invocation_id }}' AS _invocation_id
    FROM

{% if is_incremental() %}
{{ ref('bronze__transactions') }}
{% else %}
    {{ ref('bronze__transactions_fr') }}
{% endif %}
WHERE

{% if is_incremental() %}
inserted_timestamp >= (
    SELECT
        MAX(_inserted_timestamp)
    FROM
        {{ this }}
)
{% endif %}

qualify(ROW_NUMBER() over (PARTITION BY block_id_requested, tx_id
ORDER BY
    _inserted_timestamp DESC)) = 1
