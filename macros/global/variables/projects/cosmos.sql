{% macro cosmos_vars() %}
    {% set vars = {
        'GLOBAL_PROJECT_NAME': 'cosmos',
        'GLOBAL_NODE_PROVIDER': 'quicknode',
        'GLOBAL_NODE_VAULT_PATH': 'Vault/prod/cosmos/quicknode/mainnet',
        'GLOBAL_NODE_URL': '{service}/{Authentication}',
        'GLOBAL_WRAPPED_NATIVE_ASSET_ADDRESS': '',
        'MAIN_SL_BLOCKS_PER_HOUR': 3600
    } %}
    
    {{ return(vars) }}
{% endmacro %} 