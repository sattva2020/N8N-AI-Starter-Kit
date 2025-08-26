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
FORCE=false

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
  --force) FORCE=true; shift 1;;
    --bulk-file) BULK_FILE="$2"; shift 2;;
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

validate_against_schema() {
  # args: type data n8n_url token
  local _type="$1" _data="$2" _n8n="$3" _token="$4"
  # Fetch schema
  local schema_url="${_n8n%/}/rest/credentials/schema/$_type"
  echo "Checking credential schema for type '$_type' at $schema_url" >&2
  schema_resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X GET "$schema_url" -H "Authorization: Bearer $_token" -H "Accept: application/json") || true
  schema_status=$(echo "$schema_resp" | sed -n 's/.*HTTPSTATUS:\([0-9][0-9][0-9]\)$/\1/p')
  schema_body=$(echo "$schema_resp" | sed 's/\(.*\)HTTPSTATUS:[0-9][0-9][0-9]$/\1/')
  if [[ "$schema_status" != "200" ]]; then
    echo "Warning: could not fetch schema for '$_type' (HTTP $schema_status). Skipping strict validation." >&2
    return 0
  fi

  # Extract required fields from schema (if any)
  required_fields=$(echo "$schema_body" | jq -r '.required[]?') || true
  if [[ -z "$required_fields" ]]; then
    # nothing to validate
    return 0
  fi

  # For each required field, ensure _data contains it and it's not null/empty
  local missing=0
  while read -r field; do
    if [[ -z "$field" ]]; then
      continue
    fi
    # check presence
    if ! echo "$2" | jq -e "has(\"$field\") and (.[\"$field\"] != null and .[\"$field\"] != \"\")" >/dev/null 2>&1; then
      echo "Required field '$field' missing or empty in credential data for type '$_type'" >&2
      missing=1
    fi
  done <<<"$required_fields"

  if [[ $missing -ne 0 ]]; then
    if [[ "$FORCE" == "true" ]]; then
      echo "Continuing despite missing required fields because --force was set." >&2
      return 0
    else
      echo "Validation failed for credential type '$_type'. Use --force to override." >&2
      return 2
    fi
  fi
  return 0
}

payload=$(jq -n --arg name "$NAME" --arg type "$TYPE" --argjson data "$DATA" '{name: $name, type: $type, nodesAccess: [], data: $data}')

echo "Creating credential '$NAME' (type=$TYPE) at $API_URL"

# Validate before sending
if ! validate_against_schema "$TYPE" "$DATA" "$N8N_URL" "$TOKEN"; then
  echo "Aborting due to schema validation failure." >&2
  exit 2
fi

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

# Bulk processing
if [[ -n "${BULK_FILE:-}" ]]; then
  if [[ ! -f "$BULK_FILE" ]]; then
    echo "Bulk file $BULK_FILE not found" >&2
    exit 4
  fi

  # Normalize to JSON array of objects with keys: name,type,data,token(optional),n8n_url(optional)
  file_lower=$(echo "$BULK_FILE" | awk '{print tolower($0)}')
  tmp_json=$(mktemp)
  if echo "$file_lower" | grep -q '\.json$'; then
    # Ensure it's a JSON array
    jq -c '. as $in | if type=="array" then . else [.] end' "$BULK_FILE" > "$tmp_json"
    if [[ $? -ne 0 ]]; then
      echo "Failed to parse JSON bulk file" >&2
      rm -f "$tmp_json"
      exit 5
    fi
  else
    # Try CSV parsing via python to handle quoting
    python - <<PY > "$tmp_json"
import csv, json, sys
f=sys.argv[1]
rows=[]
with open(f, newline='', encoding='utf-8') as fh:
    reader=csv.DictReader(fh)
    for r in reader:
        # Expect fields: name,type,data,token(optional),n8n_url(optional)
        # data is expected to be JSON string
        if 'data' in r and r['data']:
            try:
                r['data']=json.loads(r['data'])
            except Exception:
                # leave as string
                pass
        rows.append(r)
print(json.dumps(rows))
PY
  fi

  # Iterate entries
  jq -c '.[]' "$tmp_json" | while read -r entry; do
    NAME=$(echo "$entry" | jq -r '.name')
    TYPE=$(echo "$entry" | jq -r '.type')
    # allow data to be object or string
    DATA=$(echo "$entry" | jq -c '.data')
    ENTRY_TOKEN=$(echo "$entry" | jq -r '.token // empty')
    ENTRY_N8N=$(echo "$entry" | jq -r '.n8n_url // empty')

    CUR_TOKEN=${ENTRY_TOKEN:-$TOKEN}
    CUR_N8N=${ENTRY_N8N:-$N8N_URL}

    # call API for this entry
    API_URL_RENDER="${CUR_N8N%/}/rest/credentials"
    payload=$(jq -n --arg name "$NAME" --arg type "$TYPE" --argjson data "$DATA" '{name: $name, type: $type, nodesAccess: [], data: $data}')
    echo "Creating credential: $NAME (type=$TYPE) -> $API_URL_RENDER"
    resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "$API_URL_RENDER" \
      -H "Authorization: Bearer $CUR_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload") || true
    http_status=$(echo "$resp" | sed -n 's/.*HTTPSTATUS:\([0-9][0-9][0-9]\)$/\1/p')
    body=$(echo "$resp" | sed 's/\(.*\)HTTPSTATUS:[0-9][0-9][0-9]$/\1/')
    if [[ "$http_status" == "200" || "$http_status" == "201" ]]; then
      echo "  OK: $NAME"
    else
      echo "  FAIL ($http_status): $NAME" >&2
      echo "$body" | jq . || echo "$body"
    fi
  done
  rm -f "$tmp_json"
  exit 0
fi
