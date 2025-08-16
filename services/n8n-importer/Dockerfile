FROM python:3.11-slim

# Build arg to optionally install Node/npm and n8n CLI if required by the importer
ARG INSTALL_NODE=false
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends git curl ca-certificates \
  && if [ "$INSTALL_NODE" = "true" ]; then \
  apt-get install -y --no-install-recommends gnupg2 nodejs npm; \
  npm install -g n8n; \
  fi \
  && rm -rf /var/lib/apt/lists/*

# The importer expects the host to mount the pre-cloned repository into the image at /opt/n8n-workflows
# No runtime creation or cloning of /data is performed.
COPY run-importer.sh /usr/local/bin/run-importer.sh
RUN chmod +x /usr/local/bin/run-importer.sh

WORKDIR /usr/local/bin

ENTRYPOINT ["/usr/local/bin/run-importer.sh"]
