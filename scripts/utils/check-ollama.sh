#!/bin/bash
# filepath: scripts/check-ollama.sh
set -e

# Проверка доступности Ollama API
curl --silent --fail --max-time 5 "${LLM_BINDING_HOST:-http://ollama:11434}/api/health" || exit 1

# Если проверка прошла успешно
exit 0
