#!/usr/bin/env bash
set -euo pipefail

# import_workflows_to_n8n.sh
# Usage:
#   ./scripts/import_workflows_to_n8n.sh --dir ./n8n/workflows/imported --token $N8N_ADMIN_TOKEN --n8n-url http://localhost:5678 [--dry-run]

DIR="./n8n/workflows/imported"
N8N_URL="http://localhost:5678"
TOKEN=""
DRY_RUN=false
MATCH_BY="name"   # name | tags | both | none
ACTIVATE=true      # whether to activate created/updated workflows

print_usage(){
  cat <<EOF
Usage: $0 --dir PATH --token TOKEN [--n8n-url URL] [--dry-run]

Imports all workflow JSON files (n8n export format) from DIR into n8n via REST API.
If a workflow has an "id" field the script will try to update (PUT), otherwise it will create (POST).
By default the importer will try to match existing workflows by name (use --match-by to change).
Supported --match-by values: name, tags, both, none.
Use --no-activate to prevent activating workflows after creation/update.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="$2"; shift 2;;
    --n8n-url) N8N_URL="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift 1;;
  --match-by) MATCH_BY="$2"; shift 2;;
  --no-activate) ACTIVATE=false; shift 1;;
  --activate) ACTIVATE=true; shift 1;;
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
  # extract name/tags from exported workflow content
  wf_name=$(echo "$content" | jq -r '.name // empty' 2>/dev/null || echo "")
  wf_tags_json=$(echo "$content" | jq -c '.tags // []' 2>/dev/null || echo "[]")

  if [[ -n "$wf_id" ]]; then
    echo "Found id=$wf_id — will PUT to /rest/workflows/$wf_id"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRY RUN: would PUT $f -> $N8N_URL/rest/workflows/$wf_id"
      continue
    fi
    resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X PUT "${N8N_URL%/}/rest/workflows/$wf_id" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$content") || true
  else
    # No explicit id -> try to find an existing workflow to update depending on MATCH_BY
    echo "No id field in file. Searching for existing workflow (match-by=$MATCH_BY)..."

    existing_match_id=""
    # Only query existing workflows if matching by name or tags is requested
    if [[ "$MATCH_BY" != "none" ]]; then
      existing=$(curl -sS -H "Authorization: Bearer $TOKEN" "${N8N_URL%/}/rest/workflows" 2>/dev/null || echo "[]")

      # Match by name
      if [[ ("$MATCH_BY" == "name") || ("$MATCH_BY" == "both") ]] && [[ -n "$wf_name" ]]; then
        existing_match_id=$(echo "$existing" | jq -r --arg nm "$wf_name" '.[] | select(.name==($nm)) | .id' | head -n1 || true)
      fi

      # If not found and tags matching enabled, try tags intersection
      if [[ -z "$existing_match_id" ]] && [[ ("$MATCH_BY" == "tags") || ("$MATCH_BY" == "both") ]]; then
        # If workflow has no tags, skip
        has_tags=$(echo "$wf_tags_json" | jq 'length>0') || true
        if [[ "$has_tags" == "true" ]]; then
          # iterate existing workflows and check for any tag intersection
          while IFS= read -r item; do
            ex_id=$(echo "$item" | jq -r '.id // empty')
            ex_tags_json=$(echo "$item" | jq -c '.tags // []' 2>/dev/null || echo "[]")
            if [[ "$ex_tags_json" == "[]" ]]; then
              continue
            fi
            # check intersection via jq: does any tag from wf_tags_json exist in ex_tags_json?
            inter=$(jq -n --argjson a "$wf_tags_json" --argjson b "$ex_tags_json" '
              ($a[]? as $ai | $b[]? | select(.==$ai)) // empty' 2>/dev/null || true)
            if [[ -n "$inter" ]]; then
              existing_match_id="$ex_id"
              break
            fi
          done < <(echo "$existing" | jq -c '.[]')
        fi
      fi
    fi

    if [[ -n "$existing_match_id" ]]; then
      echo "Found existing workflow id=$existing_match_id by match (will update via PUT)"
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "DRY RUN: would PUT $f -> $N8N_URL/rest/workflows/$existing_match_id"
        continue
      fi
      resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X PUT "${N8N_URL%/}/rest/workflows/$existing_match_id" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$content") || true
    else
      echo "No existing workflow matched — will POST to /rest/workflows"
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "DRY RUN: would POST $f -> $N8N_URL/rest/workflows"
        continue
      fi
      resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "${N8N_URL%/}/rest/workflows" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$content") || true
    fi
  fi

  status=$(echo "$resp" | sed -n 's/.*HTTPSTATUS:\([0-9][0-9][0-9]\)$/\1/p')
  body=$(echo "$resp" | sed 's/\(.*\)HTTPSTATUS:[0-9][0-9][0-9]$/\1/')
  if [[ "$status" == "200" || "$status" == "201" ]]; then
    echo "Success for $f"
    echo "$body" | jq .
    # attempt to activate if response contains id
    created_id=$(echo "$body" | jq -r '.id // empty')
    if [[ -n "$created_id" ]]; then
      if [[ "$ACTIVATE" == "true" ]]; then
        echo "Activating workflow $created_id"
        curl -sS -X POST "${N8N_URL%/}/rest/workflows/$created_id/activate" -H "Authorization: Bearer $TOKEN" || true
      else
        echo "Skipping activation for $created_id (activation disabled)"
      fi
    fi
  else
    echo "Failed for $f (HTTP $status)" >&2
    echo "$body" | jq . || echo "$body"
  fi
done

echo "Done."
