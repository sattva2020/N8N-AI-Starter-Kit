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
Usage: $0 [--token TOKEN | --api-key KEY] --name NAME --type TYPE --data JSON [--n8n-url URL] [--expand-env]

Example (Qdrant):
  $0 --token "TOKEN" --name "QdrantApi account" --type qdrantApi \
    --data '{"apiKey":"","url":"http://qdrant:6333"}' --n8n-url http://localhost:5678

Bulk mode (JSON/CSV):
  $0 --api-key "KEY" --bulk-file config/samples/credentials-bulk.json \
    --n8n-url https://n8n.example.com --expand-env --env-file .env

Flags:
  --expand-env   Expand 
                 \
                 ${VAR:-default} placeholders found in provided --data or bulk JSON using
                 current environment (and --env-file if present).

The script will POST to: <N8N_URL>/rest/credentials (Bearer token) or /api/v1/credentials (Public API key)
EOF
}

N8N_URL="http://localhost:5678"
TOKEN=""
NAME=""
TYPE=""
DATA=""
ENV_FILE=".env"
API_KEY=""
FORCE=false
DRY_RUN=false
BULK_FILE=""
EXPAND_ENV=false
PY_BIN=""

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
  --api-key) API_KEY="$2"; shift 2;;
    --env-file) ENV_FILE="$2"; shift 2;;
    --force) FORCE=true; shift 1;;
    --dry-run) DRY_RUN=true; shift 1;;
  --expand-env) EXPAND_ENV=true; shift 1;;
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
# Prefer explicit TOKEN, else env vars; also support API key via env
: ${TOKEN:=${N8N_ADMIN_TOKEN:-${N8N_TOKEN:-}}}
: ${API_KEY:=${N8N_API_KEY:-${N8N_PUBLIC_API_KEY:-}}}

# Detect Python interpreter (needed for CSV bulk and --expand-env)
if command -v python3 >/dev/null 2>&1; then
  PY_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PY_BIN="python"
else
  PY_BIN=""
fi
# Expand ${VAR} and ${VAR:-default} placeholders within a JSON document read from stdin.
expand_json_placeholders() {
  if [[ -z "$PY_BIN" ]]; then
    echo "--expand-env requires python3. Please install python3 or remove --expand-env." >&2
    return 9
  fi
  "$PY_BIN" - <<'PY'
import json, os, re, sys

def expand_string(s: str) -> str:
  # Replace ${VAR} and ${VAR:-default}
  pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}")

  def repl(m):
    name = m.group(1)
    default = m.group(2)
    return os.environ.get(name, default if default is not None else "")

  return pattern.sub(repl, s)

def walk(v):
  if isinstance(v, dict):
    return {k: walk(vv) for k, vv in v.items()}
  if isinstance(v, list):
    return [walk(x) for x in v]
  if isinstance(v, str):
    return expand_string(v)
  return v

src = sys.stdin.read()
# If input is empty or 'null', return as-is
if not src.strip() or src.strip() == 'null':
  sys.stdout.write(src)
  sys.exit(0)

# Try to parse JSON; if fails, return original (no expansion)
try:
  obj = json.loads(src)
except Exception:
  sys.stdout.write(src)
  sys.exit(0)
obj = walk(obj)
json.dump(obj, sys.stdout)
PY
}

# Fallback: replace ${VAR:-default} -> default, and ${VAR} -> ""
fallback_replace_defaults() {
  jq -c '
    def walk(f):
      . as $in | if type == "object" then
        reduce (keys[]) as $k ({}; . + { ($k): ($in[$k] | walk(f)) }) | f
      elif type == "array" then
        map(walk(f)) | f
      else f end;
    def repl:
      if type=="string" then
        if test("^\\$\\{[A-Za-z_][A-Za-z0-9_]*:-[^}]+\\}$") then
          capture("^\\$\\{[A-Za-z_][A-Za-z0-9_]*:-(?<def>[^}]+)\\}$").def
        elif test("^\\$\\{[A-Za-z_][A-Za-z0-9_]*\\}$") then
          ""
        else . end
      else . end;
    walk(repl)'
}


# Build auth header depending on provided credentials
auth_header() {
  # args: token api_key
  local _t="$1" _k="$2"
  if [[ -n "$_t" ]]; then
    printf '%s' "Authorization: Bearer $_t"
  elif [[ -n "$_k" ]]; then
    printf '%s' "X-N8N-API-KEY: $_k"
  else
    printf '%s' ""
  fi
}

# Normalize credential type and data to match n8n schemas
normalize_type_and_data() {
  # args: type jsonData -> echoes two lines: NEW_TYPE on line 1, NEW_DATA on line 2
  local _type="$1" _data="$2" _new_type _new_data
  _new_type="$_type"
  case "$_type" in
    qdrant) _new_type="qdrantApi" ;;
    bolt) _new_type="neo4j" ;;
    grafana) _new_type="grafanaApi" ;;
  esac

  # Use jq to normalize known shapes
  _new_data=$(jq -c --arg t "$_new_type" '
    def to_num_port: if .port? and ((.port|type)=="string") then .port |= (tonumber) else . end;
    if $t=="postgres" then
      .
      | to_num_port
      # Ensure SSH is explicitly disabled to select the non-SSH schema branch
      | (if has("sshTunnel") then . else . + {sshTunnel:"none"} end)
      | if has("ssl") then
          (if (.ssl|type)=="boolean" then .ssl = (if .ssl then "require" else "disable" end) else . end)
        else . + {ssl:"disable"} end
    elif $t=="redis" then
      (if has("url") then
        .host = (.url | sub("^redis:\/\/"; "") | split(":")[0]) |
        .port = ((.url | sub("^redis:\/\/"; "") | split(":")[1]) // "6379" | tonumber) |
        del(.url)
      else . end)
      | to_num_port
    elif $t=="neo4j" then
      . | to_num_port
    else
      .
    end' <<<"$_data")

  printf '%s\n%s\n' "$_new_type" "$_new_data"
}
# If a bulk file is provided, handle bulk processing first (safer, avoids accidental single POST)
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
    if [[ -z "$PY_BIN" ]]; then
      echo "CSV bulk requires python3. Please install python3 or provide JSON bulk file." >&2
      rm -f "$tmp_json"
      exit 5
    fi
    "$PY_BIN" - <<PY > "$tmp_json"
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
  # Optionally expand placeholders in data (skip if null/empty)
    if [[ -n "$DATA" && "$DATA" != "null" ]]; then
      if [[ "$EXPAND_ENV" == "true" ]] || echo "$DATA" | grep -q '\${'; then
        # Try Python-based expansion first
        _expanded=$(printf '%s' "$DATA" | expand_json_placeholders) || _exp_rc=$?
        _exp_rc=${_exp_rc:-0}
        if [[ $_exp_rc -eq 0 ]] && jq -e . >/dev/null 2>&1 <<<"$_expanded" && ! echo "$_expanded" | grep -q '\${'; then
          DATA="$_expanded"
        else
          # Fallback: replace ${VAR:-default} with defaults so normalization can proceed
          _fallback=$(printf '%s' "$DATA" | fallback_replace_defaults) || true
          if [[ -n "$_fallback" ]] && jq -e . >/dev/null 2>&1 <<<"$_fallback"; then
            echo "  warn: failed to fully expand placeholders (rc=${_exp_rc:-?}); applied defaults for $NAME" >&2
            DATA="$_fallback"
          else
            echo "  warn: failed to expand placeholders (rc=${_exp_rc:-?}); using original data for $NAME" >&2
          fi
        fi
        unset _expanded _exp_rc _fallback
      fi
    fi
  # Normalize line endings (strip Windows CR)
  DATA=$(printf '%s' "$DATA" | tr -d '\r')
    # Validate and compact JSON to avoid jq --argjson errors
    if ! jq -e . >/dev/null 2>&1 <<<"$DATA"; then
      echo "  FAIL: invalid JSON in 'data' for $NAME (skipping entry)" >&2
      echo "$DATA" >&2
      continue
    else
      DATA=$(jq -c . <<<"$DATA")
    fi
    # Normalize type and data to match n8n schemas
    if [[ -n "$DATA" && "$DATA" != "null" ]]; then
      mapfile -t _norm <<< "$(normalize_type_and_data "$TYPE" "$DATA")"
      if [[ ${#_norm[@]} -ge 2 ]]; then
        if [[ "$TYPE" != "${_norm[0]}" ]]; then
          echo "  note: mapped type '$TYPE' -> '${_norm[0]}'"
        fi
        TYPE="${_norm[0]}"
        DATA="${_norm[1]}"
      fi
    fi

    ENTRY_TOKEN=$(echo "$entry" | jq -r '.token // empty')
    ENTRY_APIKEY=$(echo "$entry" | jq -r '.api_key // empty')
    ENTRY_N8N=$(echo "$entry" | jq -r '.n8n_url // empty')

    CUR_TOKEN=${ENTRY_TOKEN:-$TOKEN}
    CUR_APIKEY=${ENTRY_APIKEY:-$API_KEY}
    CUR_N8N=${ENTRY_N8N:-$N8N_URL}

    # Choose endpoint depending on auth
    if [[ -n "$CUR_APIKEY" ]]; then
      API_URL_RENDER="${CUR_N8N%/}/api/v1/credentials"
    else
      API_URL_RENDER="${CUR_N8N%/}/rest/credentials"
    fi
  payload=$(jq -n --arg name "$NAME" --arg type "$TYPE" --argjson data "$DATA" '{name: $name, type: $type, nodesAccess: [], data: $data}')
    echo "Creating credential: $NAME (type=$TYPE) -> $API_URL_RENDER"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRY-RUN: payload for $NAME:" >&2
      echo "$payload" | jq .
    else
      AUTH_H=$(auth_header "$CUR_TOKEN" "$CUR_APIKEY")
      resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "$API_URL_RENDER" \
        -H "$AUTH_H" \
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
    fi
  done
  rm -f "$tmp_json"
  exit 0
fi

# If DATA not provided, try to construct a sensible default for known types
if [[ -z "$DATA" ]]; then
  # Qdrant
  if [[ "$TYPE" =~ ^(qdrantApi|qdrantapi|qdrant)$ ]]; then
    QDR_URL=${QDRANT_URL:-http://qdrant:6333}
    QDR_KEY=${QDRANT_API_KEY:-}
    DATA=$(jq -n --arg url "$QDR_URL" --arg apiKey "$QDR_KEY" '{apiKey: $apiKey, url: $url}')
  fi

  

  # Postgres credential
  if [[ "$TYPE" =~ ^(postgres|pg|postgresql)$ ]]; then
    PG_HOST=${POSTGRES_HOST:-postgres}
    PG_PORT=${POSTGRES_PORT:-5432}
    PG_DB=${POSTGRES_DB:-${N8N_DB_NAME:-n8n}}
    PG_USER=${POSTGRES_USER:-postgres}
    PG_PASS=${POSTGRES_PASSWORD:-}
    DATA=$(jq -n --arg host "$PG_HOST" --arg port "$PG_PORT" --arg database "$PG_DB" --arg user "$PG_USER" --arg password "$PG_PASS" '{host: $host, port: ($port|tonumber), database: $database, user: $user, password: $password}')
  fi

  # Neo4j / Bolt
  if [[ "$TYPE" =~ ^(neo4j|bolt)$ ]]; then
    N4_HOST=${NEO4J_HOST:-neo4j-graphiti}
    N4_PORT=${NEO4J_PORT:-7687}
    N4_USER=${NEO4J_USER:-neo4j}
    N4_PASS=${NEO4J_PASSWORD:-}
    DATA=$(jq -n --arg host "$N4_HOST" --arg port "$N4_PORT" --arg username "$N4_USER" --arg password "$N4_PASS" '{host: $host, port: ($port|tonumber), username: $username, password: $password}')
  fi
  
  # Redis
  if [[ "$TYPE" =~ ^(redis)$ ]]; then
    REDIS_URL=${REDIS_URL:-redis://redis:6379}
    REDIS_PASSWORD=${REDIS_PASSWORD:-}
    # If URL contains auth, prefer that; otherwise expose password separately
    DATA=$(jq -n --arg url "$REDIS_URL" --arg password "$REDIS_PASSWORD" '{url: $url, password: $password}')
  fi

  # Graphiti (generic API key / base URL)
  if [[ "$TYPE" =~ ^(graphiti|graphitiApi|graphiti_api)$ ]]; then
    G_API=${GRAPHITI_API_KEY:-${GRAPHITI_KEY:-}}
    G_URL=${GRAPHITI_URL:-http://graphiti:8000}
    DATA=$(jq -n --arg apiKey "$G_API" --arg url "$G_URL" '{apiKey: $apiKey, url: $url}')
  fi
fi

if [[ ( -z "$TOKEN" && -z "$API_KEY" ) || -z "$NAME" || -z "$TYPE" || -z "$DATA" ]]; then
  echo "Missing required args (token/name/type/data). You can provide --env-file to load defaults from a .env file." >&2
  print_usage
  exit 2
fi

API_URL="${N8N_URL%/}/rest/credentials"
if [[ -n "$API_KEY" ]]; then
  API_URL="${N8N_URL%/}/api/v1/credentials"
fi

validate_against_schema() {
  # args: type data n8n_url token
  local _type="$1" _data="$2" _n8n="$3" _token="$4"
  # Fetch schema (REST only). Public API обычно не предоставляет этот endpoint.
  if [[ -n "$API_KEY" ]]; then
    echo "Skipping schema validation for Public API mode" >&2
    return 0
  fi
  local schema_url="${_n8n%/}/rest/credentials/schema/$_type"
  echo "Checking credential schema for type '$_type' at $schema_url" >&2
  local _auth
  _auth=$(auth_header "$_token" "$API_KEY")
  schema_resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X GET "$schema_url" -H "$_auth" -H "Accept: application/json") || true
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

# Single credential creation path
# Expand placeholders for single payload if requested or placeholders are present
if [[ -n "$DATA" && "$DATA" != "null" ]]; then
  if [[ "$EXPAND_ENV" == "true" ]] || echo "$DATA" | grep -q '\${'; then
    _expanded=$(printf '%s' "$DATA" | expand_json_placeholders) || _exp_rc=$?
    _exp_rc=${_exp_rc:-0}
    if [[ $_exp_rc -eq 0 ]] && jq -e . >/dev/null 2>&1 <<<"$_expanded" && ! echo "$_expanded" | grep -q '\${'; then
      DATA="$_expanded"
    else
      _fallback=$(printf '%s' "$DATA" | fallback_replace_defaults) || true
      if [[ -n "$_fallback" ]] && jq -e . >/dev/null 2>&1 <<<"$_fallback"; then
        echo "warn: failed to fully expand placeholders (rc=${_exp_rc:-?}); applied defaults" >&2
        DATA="$_fallback"
      else
        echo "warn: failed to expand placeholders (rc=${_exp_rc:-?}); using original data" >&2
      fi
    fi
    unset _expanded _exp_rc _fallback
  fi
  # Normalize line endings
  DATA=$(printf '%s' "$DATA" | tr -d '\r')
  # Validate and compact JSON for single mode
  if ! jq -e . >/dev/null 2>&1 <<<"$DATA"; then
    echo "Invalid JSON provided in --data after expansion. Aborting." >&2
    echo "$DATA" >&2
    exit 2
  else
    DATA=$(jq -c . <<<"$DATA")
  fi
  # Normalize type & data
  mapfile -t _norm <<< "$(normalize_type_and_data "$TYPE" "$DATA")"
  if [[ ${#_norm[@]} -ge 2 ]]; then
    if [[ "$TYPE" != "${_norm[0]}" ]]; then
      echo "note: mapped type '$TYPE' -> '${_norm[0]}'" >&2
    fi
    TYPE="${_norm[0]}"
    DATA="${_norm[1]}"
  fi
fi

payload=$(jq -n --arg name "$NAME" --arg type "$TYPE" --argjson data "$DATA" '{name: $name, type: $type, nodesAccess: [], data: $data}')

echo "Creating credential '$NAME' (type=$TYPE) at $API_URL"

# Validate before sending
if ! validate_against_schema "$TYPE" "$DATA" "$N8N_URL" "$TOKEN"; then
  echo "Aborting due to schema validation failure." >&2
  exit 2
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN: would send payload:" >&2
  echo "$payload" | jq .
  exit 0
fi

resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "$API_URL" \
  -H "$(auth_header "$TOKEN" "$API_KEY")" \
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


# Final check to ensure script exits if no path is taken
exit 99