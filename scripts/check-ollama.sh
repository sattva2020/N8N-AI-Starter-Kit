#!/bin/bash
# filepath: scripts/check-ollama.sh
set -e

# Проверка доступности Ollama API
curl --silent --fail --max-time 5 http://ollama:11434/api/health || exit 1

# Если проверка прошла успешно
exit 0