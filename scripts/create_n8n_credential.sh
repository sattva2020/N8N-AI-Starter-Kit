#!/usr/bin/env bash
set -euo pipefail

# create_n8n_credential.sh
# Usage:
#   ./scripts/create_n8n_credential.sh --token <N8N_API_TOKEN> --name "QdrantApi account" \
#     --type qdrantApi --data '{"apiKey":"","url":"http://qdrant:6333"}' \
#     --n8n-url http://localhost:5678
#
# The script posts a new credential to n8n REST API. It requires an admin API token.

print_usage(){
  cat <<EOF
Usage: $0 --token TOKEN --name NAME --type TYPE --data JSON [--n8n-url URL]

Example (Qdrant):
  $0 --token "TOKEN" --name "QdrantApi account" --type qdrantApi \
    --data '{"apiKey":"","url":"http://qdrant:6333"}' --n8n-url http://localhost:5678

The script will POST to: <N8N_URL>/rest/credentials
EOF
}

N8N_URL="http://localhost:5678"
TOKEN=""
NAME=""
TYPE=""
DATA=""
ENV_FILE=".env"

# Try to load environment from .env if present (will be optional)
load_env_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    # shellcheck disable=SC1090
    set -a
    # source the file in a subshell style to avoid errors if it contains spaces
    # but allow simple variable assignments
    # Use `.` to source so exported variables are available
    . "$f"
    set +a
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --n8n-url) N8N_URL="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --env-file) ENV_FILE="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    --type) TYPE="$2"; shift 2;;
    --data) DATA="$2"; shift 2;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

# Load .env (defaults) if present
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  load_env_file "$ENV_FILE"
fi

# Allow reading token and n8n url from env if not provided via CLI
: ${N8N_URL:=$N8N_URL}
: ${TOKEN:=${N8N_ADMIN_TOKEN:-${N8N_TOKEN:-}}}

# If DATA not provided, try to construct a sensible default for known types
if [[ -z "$DATA" ]]; then
  if [[ "$TYPE" == "qdrantApi" || "$TYPE" == "qdrantapi" || "$TYPE" == "qdrantApi" ]]; then
    # prefer QDRANT_URL env, fallback to http://qdrant:6333
    QDR_URL=${QDRANT_URL:-${QDRANT_URL:-http://qdrant:6333}}
    QDR_KEY=${QDRANT_API_KEY:-}
    # build JSON string
    DATA=$(jq -n --arg url "$QDR_URL" --arg apiKey "$QDR_KEY" '{apiKey: $apiKey, url: $url}')
  fi
fi

if [[ -z "$TOKEN" || -z "$NAME" || -z "$TYPE" || -z "$DATA" ]]; then
  echo "Missing required args (token/name/type/data). You can provide --env-file to load defaults from a .env file." >&2
  print_usage
  exit 2
fi

API_URL="${N8N_URL%/}/rest/credentials"

payload=$(jq -n --arg name "$NAME" --arg type "$TYPE" --argjson data "$DATA" '{name: $name, type: $type, nodesAccess: [], data: $data}')

echo "Creating credential '$NAME' (type=$TYPE) at $API_URL"

resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "$API_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload") || true

http_status=$(echo "$resp" | sed -n 's/.*HTTPSTATUS:\([0-9][0-9][0-9]\)$/\1/p')
body=$(echo "$resp" | sed 's/\(.*\)HTTPSTATUS:[0-9][0-9][0-9]$/\1/')

if [[ "$http_status" == "200" || "$http_status" == "201" ]]; then
  echo "Credential created successfully."
  echo "$body" | jq .
  exit 0
else
  echo "Failed to create credential. HTTP status: $http_status" >&2
  echo "$body" | jq . || echo "$body"
  exit 3
fi
