{% macro terra_vars() %}
    {% set vars = {
        'GLOBAL_PROJECT_NAME': 'terra',
        'GLOBAL_NODE_PROVIDER': 'quicknode',
        'GLOBAL_NODE_VAULT_PATH': 'Vault/prod/terra/quicknode/mainnet',
        'GLOBAL_NODE_URL': '{service}/{Authentication}',
        'GLOBAL_WRAPPED_NATIVE_ASSET_ADDRESS': '',
        'MAIN_SL_BLOCKS_PER_HOUR': ,
        'MAIN_PRICES_NATIVE_SYMBOLS': 'LUNA'
    } %}
    
    {{ return(vars) }}
{% endmacro %} 