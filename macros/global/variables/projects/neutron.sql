{% macro neutron_vars() %}
    {% set vars = {
        'GLOBAL_PROJECT_NAME': 'neutron',
        'GLOBAL_NODE_PROVIDER': 'publicnode',
        'GLOBAL_NODE_VAULT_PATH': 'vault/prod/neutron/mainnet',
        'GLOBAL_NODE_URL': '{Service}/{Authentication}',
        'GLOBAL_WRAPPED_NATIVE_ASSET_ADDRESS': '',
        'MAIN_SL_BLOCKS_PER_HOUR': 3600
    } %}
    
    {{ return(vars) }}
{% endmacro %} 