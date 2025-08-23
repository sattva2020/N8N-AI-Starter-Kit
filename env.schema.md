# Environment schema for N8N AI Starter Kit
# This file is a schema/template for generating .env. It is intentionally
# named env.schema.md for readability but contains plain KEY=VALUE lines so
# the setup script can copy it directly to .env.

# ---- BASE SETTINGS ----
DOMAIN_NAME=sattva-ai.top

# ---- POSTGRESQL ----
# Main Database for n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=change_this_secure_password_123
POSTGRES_DB=n8n
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# ---- N8N SETTINGS ----
N8N_ENCRYPTION_KEY=your_32_char_encryption_key_here_
N8N_USER_MANAGEMENT_JWT_SECRET=your_jwt_secret_key_here_min_32_chars
N8N_DEFAULT_BINARY_DATA_MODE=filesystem
N8N_HOST=n8n.${DOMAIN_NAME}
N8N_PORT=5678
N8N_PROTOCOL=http
N8N_SECURE_COOKIE=false
WEBHOOK_URL=http://${N8N_HOST}/
N8N_API_KEY=your_n8n_api_key_here
N8N_API_AUTH_ACTIVE=true

# ---- DOMAINS FOR DEVELOPMENT ----
N8N_DOMAIN=n8n.${DOMAIN_NAME}
WEB_INTERFACE_DOMAIN=web.${DOMAIN_NAME}
DOCUMENT_PROCESSOR_DOMAIN=doc-processor.${DOMAIN_NAME}
QDRANT_DOMAIN=qdrant.${DOMAIN_NAME}
OLLAMA_DOMAIN=ollama.${DOMAIN_NAME}
TRAEFIK_DASHBOARD_DOMAIN=traefik.${DOMAIN_NAME}

# ---- OLLAMA SETTINGS ----
# Ollama models are defined in config/ollama-models-config.yml
# Remove MODEL/MODELS/model_name from environment files to avoid duplication

# ---- SYSTEM SETTINGS ----
GENERIC_TIMEZONE=UTC
NODE_ENV=production
COMPOSE_PROJECT_NAME=n8n-ai-starter-kit

# ---- PGADMIN ----
PGADMIN_DEFAULT_EMAIL=change_me@example.com
PGADMIN_DEFAULT_PASSWORD=pgadmin_secure_password_123

# ---- TRAEFIK ----
ACME_EMAIL=change_me@example.com
TRAEFIK_USERNAME=admin
TRAEFIK_PASSWORD_HASHED=traefik_password_hash_placeholder

# ---- GRAPHITI ----
OPENAI_API_KEY=your_openai_api_key_here
GRAPHITI_DOMAIN=graphiti.${DOMAIN_NAME}

# ---- NEO4J ----
NEO4J_URI=bolt://neo4j-graphiti:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=change_this_secure_password_123
NEO4J_HOST=neo4j-graphiti
NEO4J_PORT=7687
NEO4J_BOLT_PORT=7687
NEO4J_HTTP_PORT=7474

# ---- PRODUCTION DOMAINS ----
N8N_DOMAIN=n8n.${DOMAIN_NAME}
OLLAMA_DOMAIN=ollama.${DOMAIN_NAME}
QDRANT_DOMAIN=qdrant.${DOMAIN_NAME}
PGADMIN_DOMAIN=pgadmin.${DOMAIN_NAME}
JUPYTER_DOMAIN=jupyter.${DOMAIN_NAME}
TRAEFIK_DASHBOARD_DOMAIN=traefik.${DOMAIN_NAME}
GRAPHITI_DOMAIN=graphiti.${DOMAIN_NAME}
DOCUMENT_PROCESSOR_DOMAIN=doc-processor.${DOMAIN_NAME}
WEB_INTERFACE_DOMAIN=web.${DOMAIN_NAME}

# ---- DOCUMENT PROCESSOR ----
DOCUMENT_PROCESSOR_MAX_FILE_SIZE=100MB
DOCUMENT_PROCESSOR_SUPPORTED_FORMATS=pdf,docx,txt,md,rtf
DOCUMENT_PROCESSOR_CHUNK_SIZE=512
DOCUMENT_PROCESSOR_OVERLAP=50
DOCUMENT_PROCESSOR_TIMEOUT=300

# ---- ADDITIONAL SETTINGS ----
N8N_SECURE_COOKIE=false
N8N_METRICS=true

# Database settings
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}

# N8N reset behavior (default false in compose)
N8N_RESET=false

# Workflows Documentation Domain
WORKFLOWS_DOC_DOMAIN=workflows.${DOMAIN_NAME}
WORKFLOWS_MANAGER_DOMAIN=workflows-manager.${DOMAIN_NAME}
WORKFLOWS_MANAGER_API_KEY=

# ---- DEFAULTS / SUGGESTIONS ----
# These are safe defaults for local/testing. Replace secrets in the generated
# .env file. Do NOT commit secrets to the repository.

# Grafana defaults (change in production)
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123

# Jupyter
JUPYTER_TOKEN=change_me

# Clickhouse (optional)
CLICKHOUSE_PASSWORD=change_me

# Superset
SUPERSET_SECRET_KEY=change_me

# Ollama host
OLLAMA_HOST=ollama

# n8n task runners
N8N_RUNNERS_ENABLED=true

# NOTE: After generating .env, please replace placeholders for keys and
# passwords (OPENAI_API_KEY, N8N_API_KEY, POSTGRES_PASSWORD, NEO4J_PASSWORD, etc.).
