FROM python:3.9.23-slim

# Install runtime deps: git for cloning, node/npm for n8n CLI
RUN apt-get update \
  && apt-get install -y --no-install-recommends git curl ca-certificates gnupg nodejs npm \
  && npm install -g n8n \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy small launcher script
COPY run-importer.sh /usr/local/bin/run-importer.sh
RUN chmod +x /usr/local/bin/run-importer.sh

ENTRYPOINT ["/usr/local/bin/run-importer.sh"]
