{% macro return_vars() %}
  {# This macro sets and returns all configurable variables used throughout the project,
     organizing them by category (Global, Bronze, Silver, Streamline, Decoder etc.) with default values.
     IMPORTANT: Only call get_var() once per variable #}
  
  {# Set all variables on the namespace #}
  {% set ns = namespace() %}
  
  {# Set Variables and Default Values, organized by category #}
  
  {# Global Variables #}
  {% set ns.GLOBAL_PROJECT_NAME = get_var('GLOBAL_PROJECT_NAME', '') %}
  {% set ns.GLOBAL_NODE_PROVIDER = get_var('GLOBAL_NODE_PROVIDER', '') %}
  {% set ns.GLOBAL_NODE_URL = get_var('GLOBAL_NODE_URL', '{Service}/{Authentication}') %}
  {% set ns.GLOBAL_WRAPPED_NATIVE_ASSET_ADDRESS = get_var('GLOBAL_WRAPPED_NATIVE_ASSET_ADDRESS', '') %}
  {% set ns.GLOBAL_MAX_SEQUENCE_NUMBER = get_var('GLOBAL_MAX_SEQUENCE_NUMBER', 1000000000) %}
  {% set ns.GLOBAL_NODE_VAULT_PATH = get_var('GLOBAL_NODE_VAULT_PATH', '') %}
  {% set ns.GLOBAL_NETWORK = get_var('GLOBAL_NETWORK', 'mainnet') %}

  {% set ns.GLOBAL_BRONZE_FR_ENABLED = none if get_var('GLOBAL_BRONZE_FR_ENABLED', false) else false %} {# Sets to none if true, still requires --full-refresh, otherwise will use incremental #}
  {% set ns.GLOBAL_SILVER_FR_ENABLED = none if get_var('GLOBAL_SILVER_FR_ENABLED', false) else false %} 
  {% set ns.GLOBAL_GOLD_FR_ENABLED = none if get_var('GLOBAL_GOLD_FR_ENABLED', false) else false %} 
  {% set ns.GLOBAL_STREAMLINE_FR_ENABLED = none if get_var('GLOBAL_STREAMLINE_FR_ENABLED', false) else false %} 
  {% set ns.GLOBAL_NEW_BUILD_ENABLED = get_var('GLOBAL_NEW_BUILD_ENABLED', false) %}
  
  {# GHA Workflow Variables #}
  {% set ns.MAIN_GHA_STREAMLINE_CHAINHEAD_CRON = get_var('MAIN_GHA_STREAMLINE_CHAINHEAD_CRON', '0,30 * * * *') %}
  {% set ns.MAIN_GHA_SCHEDULED_MAIN_CRON = get_var('MAIN_GHA_SCHEDULED_MAIN_CRON', none) %}
  {% set ns.MAIN_GHA_SCHEDULED_CURATED_CRON = get_var('MAIN_GHA_SCHEDULED_CURATED_CRON', none) %}
  {% set ns.MAIN_GHA_SCHEDULED_ABIS_CRON = get_var('MAIN_GHA_SCHEDULED_ABIS_CRON', none) %}
  {% set ns.MAIN_GHA_SCHEDULED_SCORES_CRON = get_var('MAIN_GHA_SCHEDULED_SCORES_CRON', none) %}
  {% set ns.MAIN_GHA_TEST_DAILY_CRON = get_var('MAIN_GHA_TEST_DAILY_CRON', none) %}
  {% set ns.MAIN_GHA_TEST_INTRADAY_CRON = get_var('MAIN_GHA_TEST_INTRADAY_CRON', none) %}
  {% set ns.MAIN_GHA_TEST_MONTHLY_CRON = get_var('MAIN_GHA_TEST_MONTHLY_CRON', none) %}
  {% set ns.MAIN_GHA_FULL_OBSERVABILITY_CRON = get_var('MAIN_GHA_FULL_OBSERVABILITY_CRON', none) %}
  {% set ns.MAIN_GHA_DEV_REFRESH_CRON = get_var('MAIN_GHA_DEV_REFRESH_CRON', none) %}
  {% set ns.MAIN_GHA_STREAMLINE_DECODER_HISTORY_CRON = get_var('MAIN_GHA_STREAMLINE_DECODER_HISTORY_CRON', none) %}

  {# Main Streamline Variables #}
  {% set ns.MAIN_SL_BLOCKS_PER_HOUR = get_var('MAIN_SL_BLOCKS_PER_HOUR', 1) %}
  {% set ns.MAIN_SL_TRANSACTIONS_PER_BLOCK = get_var('MAIN_SL_TRANSACTIONS_PER_BLOCK', 1) %}
  {% set ns.MAIN_SL_TESTING_LIMIT = get_var('MAIN_SL_TESTING_LIMIT', none) %}
  {% set ns.MAIN_SL_NEW_BUILD_ENABLED = get_var('MAIN_SL_NEW_BUILD_ENABLED', false) %}
  {% set ns.MAIN_SL_MIN_BLOCK = get_var('MAIN_SL_MIN_BLOCK', none) %}
  {% set ns.MAIN_SL_CHAINHEAD_DELAY_MINUTES = get_var('MAIN_SL_CHAINHEAD_DELAY_MINUTES', 3) %}
  {% set ns.MAIN_SL_BLOCK_LOOKBACK_ENABLED = get_var('MAIN_SL_BLOCK_LOOKBACK_ENABLED', true) %}
  
  {# SL Blocks Variables #}
  {% set ns.MAIN_SL_BLOCKS_REALTIME_SQL_LIMIT = get_var('MAIN_SL_BLOCKS_REALTIME_SQL_LIMIT', 2 * ns.MAIN_SL_BLOCKS_PER_HOUR) %}
  {% set ns.MAIN_SL_BLOCKS_REALTIME_PRODUCER_BATCH_SIZE = get_var('MAIN_SL_BLOCKS_REALTIME_PRODUCER_BATCH_SIZE', 2 * ns.MAIN_SL_BLOCKS_PER_HOUR) %}
  {% set ns.MAIN_SL_BLOCKS_REALTIME_WORKER_BATCH_SIZE = get_var('MAIN_SL_BLOCKS_REALTIME_WORKER_BATCH_SIZE', ns.MAIN_SL_BLOCKS_PER_HOUR) %}
  {% set ns.MAIN_SL_BLOCKS_REALTIME_ASYNC_CONCURRENT_REQUESTS = get_var('MAIN_SL_BLOCKS_REALTIME_ASYNC_CONCURRENT_REQUESTS', 100) %}
  
  {# SL Transactions Variables #}
  {% set ns.MAIN_SL_TRANSACTIONS_REALTIME_SQL_LIMIT = get_var('MAIN_SL_TRANSACTIONS_REALTIME_SQL_LIMIT', 2 * ns.MAIN_SL_BLOCKS_PER_HOUR) %}
  {% set ns.MAIN_SL_TRANSACTIONS_REALTIME_PRODUCER_BATCH_SIZE = get_var('MAIN_SL_TRANSACTIONS_REALTIME_PRODUCER_BATCH_SIZE', 2 * ns.MAIN_SL_BLOCKS_PER_HOUR) %}
  {% set ns.MAIN_SL_TRANSACTIONS_REALTIME_WORKER_BATCH_SIZE = get_var('MAIN_SL_TRANSACTIONS_REALTIME_WORKER_BATCH_SIZE', ns.MAIN_SL_BLOCKS_PER_HOUR) %}
  {% set ns.MAIN_SL_TRANSACTIONS_REALTIME_ASYNC_CONCURRENT_REQUESTS = get_var('MAIN_SL_TRANSACTIONS_REALTIME_ASYNC_CONCURRENT_REQUESTS', 100) %}
  
  {# SL Transaction Counts Variables #}
  {% set ns.MAIN_SL_TX_COUNTS_REALTIME_SQL_LIMIT = get_var('MAIN_SL_TX_COUNTS_REALTIME_SQL_LIMIT', 2 * ns.MAIN_SL_BLOCKS_PER_HOUR * ns.MAIN_SL_TRANSACTIONS_PER_BLOCK) %}
  {% set ns.MAIN_SL_TX_COUNTS_REALTIME_PRODUCER_BATCH_SIZE = get_var('MAIN_SL_TX_COUNTS_REALTIME_PRODUCER_BATCH_SIZE', 2 * ns.MAIN_SL_BLOCKS_PER_HOUR * ns.MAIN_SL_TRANSACTIONS_PER_BLOCK) %}
  {% set ns.MAIN_SL_TX_COUNTS_REALTIME_WORKER_BATCH_SIZE = get_var('MAIN_SL_TX_COUNTS_REALTIME_WORKER_BATCH_SIZE', ns.MAIN_SL_BLOCKS_PER_HOUR * ns.MAIN_SL_TRANSACTIONS_PER_BLOCK) %}
  {% set ns.MAIN_SL_TX_COUNTS_REALTIME_ASYNC_CONCURRENT_REQUESTS = get_var('MAIN_SL_TX_COUNTS_REALTIME_ASYNC_CONCURRENT_REQUESTS', 100) %}
  
  {# Observability Variables #}
  {% set ns.MAIN_OBSERV_FULL_TEST_ENABLED = get_var('MAIN_OBSERV_FULL_TEST_ENABLED', false) %}
  {% set ns.MAIN_OBSERV_BLOCKS_EXCLUSION_LIST_ENABLED = get_var('MAIN_OBSERV_BLOCKS_EXCLUSION_LIST_ENABLED', false) %}
  {% set ns.MAIN_OBSERV_LOGS_EXCLUSION_LIST_ENABLED = get_var('MAIN_OBSERV_LOGS_EXCLUSION_LIST_ENABLED', false) %}
  {% set ns.MAIN_OBSERV_RECEIPTS_EXCLUSION_LIST_ENABLED = get_var('MAIN_OBSERV_RECEIPTS_EXCLUSION_LIST_ENABLED', false) %}
  {% set ns.MAIN_OBSERV_TRACES_EXCLUSION_LIST_ENABLED = get_var('MAIN_OBSERV_TRACES_EXCLUSION_LIST_ENABLED', false) %}
  {% set ns.MAIN_OBSERV_TRANSACTIONS_EXCLUSION_LIST_ENABLED = get_var('MAIN_OBSERV_TRANSACTIONS_EXCLUSION_LIST_ENABLED', false) %}
  
  {# Prices Variables #}
  {% set ns.MAIN_PRICES_NATIVE_SYMBOLS = get_var('MAIN_PRICES_NATIVE_SYMBOLS', '') %}
  {% set ns.MAIN_PRICES_NATIVE_BLOCKCHAINS = get_var('MAIN_PRICES_NATIVE_BLOCKCHAINS', ns.GLOBAL_PROJECT_NAME.lower()) %}
  {% set ns.MAIN_PRICES_PROVIDER_PLATFORMS = get_var('MAIN_PRICES_PROVIDER_PLATFORMS', '') %}
  {% set ns.MAIN_PRICES_TOKEN_ADDRESSES = get_var('MAIN_PRICES_TOKEN_ADDRESSES', none) %}
  {% set ns.MAIN_PRICES_TOKEN_BLOCKCHAINS = get_var('MAIN_PRICES_TOKEN_BLOCKCHAINS', ns.GLOBAL_PROJECT_NAME.lower()) %}

  {# Labels Variables #}
  {% set ns.MAIN_LABELS_BLOCKCHAINS = get_var('MAIN_LABELS_BLOCKCHAINS', ns.GLOBAL_PROJECT_NAME.lower()) %}

  {# Scores Variables #}
  {% set ns.SCORES_FULL_RELOAD_ENABLED = get_var('SCORES_FULL_RELOAD_ENABLED', false) %}
  {% set ns.SCORES_LIMIT_DAYS = get_var('SCORES_LIMIT_DAYS', 30) %}

  {# Return the entire namespace as a dictionary #}
  {{ return(ns) }}
{% endmacro %}