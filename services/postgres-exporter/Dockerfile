FROM quay.io/prometheuscommunity/postgres-exporter:latest

# Custom queries and configuration
COPY queries.yaml /etc/postgres_exporter/

# Environment variables will be set by docker-compose
ENV DATA_SOURCE_NAME=""
ENV PG_EXPORTER_WEB_LISTEN_ADDRESS=":9187"
ENV PG_EXPORTER_EXTEND_QUERY_PATH="/etc/postgres_exporter/queries.yaml"

EXPOSE 9187

USER nobody

ENTRYPOINT ["/bin/postgres_exporter"]
