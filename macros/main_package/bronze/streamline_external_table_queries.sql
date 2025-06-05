{% macro streamline_external_table_query(
    source_name,
    partition_function="CAST(SPLIT_PART(SPLIT_PART(file_name, '/', 4), '_', 1) AS INTEGER)"
    ) %}

    {% set days = var("BRONZE_LOOKBACK_DAYS")%}

    WITH meta AS (
        SELECT
            last_modified AS inserted_timestamp,
            file_name,
            {{ partition_function }} AS partition_key
        FROM
            TABLE(
                information_schema.external_table_file_registration_history(
                    start_time => DATEADD('day', -ABS({{days}}), CURRENT_TIMESTAMP()),
                    table_name => '{{ source( "bronze_streamline", source_name) }}')
                ) A
        )
        SELECT
            s.*,
            b.file_name,
            inserted_timestamp
        FROM
            {{ source("bronze_streamline", source_name) }} s
            JOIN meta b
            ON b.file_name = metadata$filename
            AND b.partition_key = s.partition_key
        WHERE
            b.partition_key = s.partition_key
{% endmacro %}

{% macro streamline_external_table_query_fr(
        source_name,
        partition_function="CAST(SPLIT_PART(SPLIT_PART(file_name, '/', 4), '_', 1) AS INTEGER)"
    ) %}
    WITH meta AS (
        SELECT
            registered_on AS inserted_timestamp,
            file_name,
            {{ partition_function }} AS partition_key
        FROM
            TABLE(
                information_schema.external_table_files(
                    table_name => '{{ source( "bronze_streamline", source_name) }}'
                )
            ) A
    )
SELECT
    s.*,
    b.file_name,
    inserted_timestamp
FROM
    {{ source(
        "bronze_streamline",
        source_name
    ) }}
    s
    JOIN meta b
    ON b.file_name = metadata$filename
    AND b.partition_key = s.partition_key
WHERE
    b.partition_key = s.partition_key
{% endmacro %}