{{ config(
    materialized = 'incremental',
    unique_key = ['tx_id'],
    incremental_strategy = 'merge',
    cluster_by = ['block_timestamp::DATE'],
    tags = ['silver', 'core', 'phase_2']
) }}

WITH event_attributes AS (
    SELECT
        t.block_id,
        t.block_timestamp,
        t.tx_id,
        t.tx_succeeded,
        t.tx_code,
        t.codespace,
        COALESCE(l.value:msg_index::INTEGER, 0) as msg_index,
        e.value:type::STRING as event_type,
        ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'key', a.value:key::STRING,
                'value', COALESCE(a.value:value::STRING, '')
            )
        ) as attributes,
        t._inserted_timestamp
    FROM {{ ref('silver__transactions') }} t,
    LATERAL FLATTEN(input => PARSE_JSON(t.tx_log)) l,
    LATERAL FLATTEN(input => l.value:events) e,
    LATERAL FLATTEN(input => e.value:attributes) a
    WHERE t.tx_log IS NOT NULL
    AND t.tx_succeeded = TRUE
    AND IS_OBJECT(PARSE_JSON(t.tx_log))
    {% if is_incremental() %}
    AND t._inserted_timestamp >= (
        SELECT MAX(_inserted_timestamp)
        FROM {{ this }}
    )
    {% endif %}
    GROUP BY 
        t.block_id,
        t.block_timestamp,
        t.tx_id,
        t.tx_succeeded,
        t.tx_code,
        t.codespace,
        l.value:msg_index,
        e.value:type,
        t._inserted_timestamp
),

parsed_logs AS (
    SELECT
        block_id,
        block_timestamp,
        tx_id,
        tx_succeeded,
        tx_code,
        codespace,
        ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'msg_index', msg_index,
                'event_type', event_type,
                'attributes', attributes
            )
        ) WITHIN GROUP (ORDER BY msg_index, event_type) as tx_log,
        _inserted_timestamp
    FROM event_attributes
    GROUP BY 
        block_id,
        block_timestamp,
        tx_id,
        tx_succeeded,
        tx_code,
        codespace,
        _inserted_timestamp
),

failed_txs AS (
    SELECT
        t.block_id,
        t.block_timestamp,
        t.tx_id,
        t.tx_succeeded,
        t.tx_code,
        t.codespace,
        ARRAY_CONSTRUCT(
            OBJECT_CONSTRUCT(
                'msg_index', 0,
                'event_type', 'error',
                'attributes', ARRAY_CONSTRUCT(
                    OBJECT_CONSTRUCT(
                        'key', 'error_message',
                        'value', t.tx_log::STRING
                    )
                )
            )
        ) as tx_log,
        t._inserted_timestamp
    FROM {{ ref('silver__transactions') }} t
    WHERE t.tx_succeeded = FALSE
    AND t.tx_log IS NOT NULL
    {% if is_incremental() %}
    AND t._inserted_timestamp >= (
        SELECT MAX(_inserted_timestamp)
        FROM {{ this }}
    )
    {% endif %}
)

SELECT
    block_id,
    block_timestamp,
    tx_id,
    tx_succeeded,
    tx_code,
    codespace,
    tx_log,
    {{ dbt_utils.generate_surrogate_key(['tx_id']) }} as transactions_logs_id,
    _inserted_timestamp,
    CURRENT_TIMESTAMP() as inserted_timestamp,
    CURRENT_TIMESTAMP() as modified_timestamp,
    '{{ invocation_id }}' as _invocation_id
FROM (
    SELECT * FROM parsed_logs
    UNION ALL
    SELECT * FROM failed_txs
) t
QUALIFY ROW_NUMBER() OVER (PARTITION BY tx_id ORDER BY _inserted_timestamp DESC) = 1
ORDER BY block_timestamp, tx_id