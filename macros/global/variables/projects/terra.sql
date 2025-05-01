{% macro terra_vars() %}
    {% set vars = {
        'API_INTEGRATION_PROD': 'aws_ton_api_prod_v2',
        'API_INTEGRATION_DEV': 'aws_ton_api_dev_v2',
        'GLOBAL_PROJECT_NAME': 'terra',
        'GLOBAL_NODE_PROVIDER': 'quicknode',
        'GLOBAL_NODE_VAULT_PATH': 'Vault/prod/terra/quicknode/mainnet',
        'GLOBAL_NODE_URL': '{service}/{Authentication}',
        'GLOBAL_WRAPPED_NATIVE_ASSET_ADDRESS': '0x82af49447d8a07e3bd95bd0d56f35241523fbab1',
        'MAIN_SL_BLOCKS_PER_HOUR': 14200,
        'MAIN_PRICES_NATIVE_SYMBOLS': 'ETH'
    } %}
    
    {{ return(vars) }}
{% endmacro %} 