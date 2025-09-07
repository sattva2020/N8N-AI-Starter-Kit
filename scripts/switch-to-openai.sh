#!/usr/bin/env bash
# Safe helper to switch this repo/environment to use OpenAI API bindings
# - backs up existing .env
# - sets LLM_BINDING and EMBEDDING_BINDING to "openai"
# - ensures OPENAI_API_KEY exists (writes placeholder if missing)
# - prints explicit next steps (set real key, restart services)

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
TS=$(date -u +%Y%m%dT%H%M%SZ)

echo "Switching project to use OpenAI API bindings"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env file found at $ENV_FILE. Creating from template.env if present..."
  if [ -f "$ROOT_DIR/template.env" ]; then
    cp "$ROOT_DIR/template.env" "$ENV_FILE"
    echo "Created $ENV_FILE from template.env"
  else
    echo "No template.env found. Creating empty .env"
    touch "$ENV_FILE"
  fi
fi

cp "$ENV_FILE" "${ENV_FILE}.bak.$TS"
echo "Backed up existing .env to ${ENV_FILE}.bak.$TS"

# helper to upsert key=value in .env
upsert_env() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "$ENV_FILE"; then
    sed -i.bak -E "s#^${key}=.*#${key}=${value}#g" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

upsert_env "LLM_BINDING" "openai"
upsert_env "EMBEDDING_BINDING" "openai"

# Ensure OPENAI_API_KEY exists but do not attempt to set a real secret here
if ! grep -qE "^OPENAI_API_KEY=" "$ENV_FILE"; then
  echo "OPENAI_API_KEY=your_openai_api_key_here" >> "$ENV_FILE"
  echo "Wrote placeholder OPENAI_API_KEY in .env — replace with your real key before starting services."
else
  echo "OPENAI_API_KEY already present in .env (leave as-is)."
fi

echo
echo "Resulting bindings in $ENV_FILE:"
grep -E "^LLM_BINDING=|^EMBEDDING_BINDING=|^OPENAI_API_KEY=" "$ENV_FILE" || true

cat <<'EOF'
Next steps (manual):
1) Edit .env and set OPENAI_API_KEY to your actual key (do NOT commit this file).
2) Restart services so they pick up the new env (example):
   docker compose down && docker compose up -d
   OR if you prefer:
   docker compose up -d --build
3) Run validation:
   ./scripts/validate-all-services.sh

If you want me to also update other scripts that explicitly check Ollama (for example `scripts/utils/check-ollama.sh`), say so and I will prepare safe edits to prefer OpenAI when LLM_BINDING=openai.
EOF

echo "Done. .env was backed up and updated."
