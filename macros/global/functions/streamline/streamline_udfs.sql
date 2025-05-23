{% macro create_udf_bulk_rest_api_v2() %}    
    {{ log("Creating udf udf_bulk_rest_api for target:" ~ target.name ~ ", schema: " ~ target.schema ~ ", DB: " ~ target.database, info=True) }}
    {{ log("role:" ~ target.role ~ ", user:" ~ target.user, info=True) }}

    {% set sql %}
    CREATE OR REPLACE EXTERNAL FUNCTION streamline.udf_bulk_rest_api_v2(json object) returns array api_integration = 
    {% if target.name == "prod" %} 
        {{ log("Creating prod udf_bulk_rest_api_v2", info=True) }}
        {{ var("API_INTEGRATION") }} AS 'https://{{ var("EXTERNAL_FUNCTION_URI") | lower }}udf_bulk_rest_api'
    {% elif target.name == "dev" %}
        {{ log("Creating dev udf_bulk_rest_api_v2", info=True) }}
        {{ var("API_INTEGRATION") }} AS 'https://{{ var("EXTERNAL_FUNCTION_URI") | lower }}udf_bulk_rest_api'
    {% else %}
        {{ log("Creating default (dev) udf_bulk_rest_api_v2", info=True) }}
        {{ var("config")["dev"]["API_INTEGRATION"] }} AS 'https://{{ var("config")["dev"]["EXTERNAL_FUNCTION_URI"] | lower }}udf_bulk_rest_api'
    {% endif %};
    {% endset %}
    {{ log(sql, info=True) }}
    {% do adapter.execute(sql) %}
{% endmacro %}