#!/usr/bin/env bash
set -euo pipefail

# import_workflows_to_n8n.sh
# Usage:
#   ./scripts/import_workflows_to_n8n.sh --dir ./n8n/workflows/imported --token $N8N_ADMIN_TOKEN --n8n-url http://localhost:5678 [--dry-run]

DIR="./n8n/workflows/imported"
N8N_URL="http://localhost:5678"
TOKEN=""
DRY_RUN=false

print_usage(){
  cat <<EOF
Usage: $0 --dir PATH --token TOKEN [--n8n-url URL] [--dry-run]

Imports all workflow JSON files (n8n export format) from DIR into n8n via REST API.
If a workflow has an "id" field the script will try to update (PUT), otherwise it will create (POST).
After creating a workflow the script can optionally activate it.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2;;
    --n8n-url) N8N_URL="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift 1;;
    -h|--help) print_usage; exit 0;;
    *) echo "Unknown arg: $1"; print_usage; exit 1;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "Missing --token. Provide N8N admin token or use --env-file in a wrapper." >&2
  exit 2
fi

if [[ ! -d "$DIR" ]]; then
  echo "Directory $DIR not found" >&2
  exit 3
fi

for f in "$DIR"/*.json; do
  [[ -e "$f" ]] || continue
  echo "Processing $f"
  content=$(cat "$f")
  wf_id=$(echo "$content" | jq -r '.id // empty') || true

  if [[ -n "$wf_id" ]]; then
    echo "Found id=$wf_id — will PUT to /rest/workflows/$wf_id"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRY RUN: would PUT $f -> $N8N_URL/rest/workflows/$wf_id"
      continue
    fi
    resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X PUT "${N8N_URL%/}/rest/workflows/$wf_id" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$content") || true
  else
    echo "No id field — will POST to /rest/workflows"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRY RUN: would POST $f -> $N8N_URL/rest/workflows"
      continue
    fi
    resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "${N8N_URL%/}/rest/workflows" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$content") || true
  fi

  status=$(echo "$resp" | sed -n 's/.*HTTPSTATUS:\([0-9][0-9][0-9]\)$/\1/p')
  body=$(echo "$resp" | sed 's/\(.*\)HTTPSTATUS:[0-9][0-9][0-9]$/\1/')
  if [[ "$status" == "200" || "$status" == "201" ]]; then
    echo "Success for $f"
    echo "$body" | jq .
    # attempt to activate if response contains id
    created_id=$(echo "$body" | jq -r '.id // empty')
    if [[ -n "$created_id" ]]; then
      echo "Activating workflow $created_id"
      curl -sS -X POST "${N8N_URL%/}/rest/workflows/$created_id/activate" -H "Authorization: Bearer $TOKEN" || true
    fi
  else
    echo "Failed for $f (HTTP $status)" >&2
    echo "$body" | jq . || echo "$body"
  fi
done

echo "Done."
