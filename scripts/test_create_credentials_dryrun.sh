#!/usr/bin/env bash
set -euo pipefail

# Helper: safe dry-run for create_n8n_credential.sh
# Usage: ./scripts/test_create_credentials_dryrun.sh

SCRIPT="$(dirname "$0")/create_n8n_credential.sh"
if [[ ! -x "$SCRIPT" ]]; then
  echo "Make sure $SCRIPT is executable (chmod +x)." >&2
  exit 2
fi

if [[ -z "${N8N_ADMIN_TOKEN:-}" ]]; then
  echo "Please set N8N_ADMIN_TOKEN in your environment or .env before running this test." >&2
  exit 3
fi

echo "Running dry-run single credential creation (Qdrant)..."
"$SCRIPT" --dry-run --token "$N8N_ADMIN_TOKEN" --name "qdrant-test" --type qdrantApi || true

echo "Running dry-run bulk sample (JSON inline)..."
cat > /tmp/credentials_sample.json <<JSON
[
  {"name":"qdrant-test-bulk","type":"qdrantApi","data":{"url":"http://qdrant:6333","apiKey":""}},
  {"name":"minio-test","type":"awsS3","data":{"accessKeyId":"miniouser","secretAccessKey":"miniosecret","endpoint":"http://minio:9000","region":"us-east-1"}}
]
JSON

"$SCRIPT" --bulk-file /tmp/credentials_sample.json --dry-run --token "$N8N_ADMIN_TOKEN" || true

echo "Dry-run tests complete. Review the above payloads to ensure correctness."
