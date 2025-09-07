#!/usr/bin/env bash
set -euo pipefail
# Скрипт для копирования и запуска теста GraphRAG на удалённом сервере

# Параметры:
#   1: SSH-пользователь и хост (по умолчанию root@37.53.91.144)
#   2: Путь к приватному ключу SSH (по умолчанию ~/.ssh/id_rsa_n8n)
#   3: Локальный путь к тестовому скрипту (по умолчанию .internal/graphrag-official/test_graphrag_with_ollama.py)
#   4: Удалённая директория (по умолчанию /opt/graphrag)

SERVER="${1:-root@37.53.91.144}"
SSH_KEY="${2:-$HOME/.ssh/id_rsa_n8n}"
LOCAL_SCRIPT="${3:-.internal/graphrag-official/test_graphrag_with_ollama.py}"
REMOTE_DIR="${4:-/opt/graphrag}"

# Use the basename so the remote copy and execution match the provided script
REMOTE_BASENAME="$(basename "${LOCAL_SCRIPT}")"

if [ ! -f "${LOCAL_SCRIPT}" ]; then
  echo "❌ Локальный скрипт '${LOCAL_SCRIPT}' не найден"
  exit 1
fi

echo "📤 Копирование скрипта ${LOCAL_SCRIPT} на ${SERVER}:${REMOTE_DIR}/${REMOTE_BASENAME}..."
scp -i "${SSH_KEY}" "${LOCAL_SCRIPT}" "${SERVER}:${REMOTE_DIR}/${REMOTE_BASENAME}"

echo "🔑 Подключение к ${SERVER} и запуск теста..."
# Pass REMOTE_DIR to the remote shell so we don't rely on local heredoc expansion
ssh -i "${SSH_KEY}" "${SERVER}" "REMOTE_DIR='${REMOTE_DIR}' REMOTE_SCRIPT='${REMOTE_BASENAME}' bash -s" <<'EOF'
set -euo pipefail
cd "${REMOTE_DIR}"
# Ensure conda installed in common locations is on PATH for non-login shells
export PATH="/root/miniconda/bin:${HOME}/miniconda3/bin:${HOME}/.local/miniconda/bin:$PATH"

# Try conda-based activation first (non-interactive)
if command -v conda >/dev/null 2>&1; then
  # Prefer sourcing installed conda's profile.d if present; otherwise use shell hook
  if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    . "${HOME}/miniconda3/etc/profile.d/conda.sh"
  elif [ -f "${HOME}/.local/miniconda/etc/profile.d/conda.sh" ]; then
    . "${HOME}/.local/miniconda/etc/profile.d/conda.sh"
  elif [ -f "/root/miniconda/etc/profile.d/conda.sh" ]; then
    . "/root/miniconda/etc/profile.d/conda.sh"
  else
    # Fallback: initialize conda in this shell
    eval "$(conda shell.bash hook)" || true
  fi
  echo "Using conda to activate 'graphrag'..."
  conda activate graphrag || { echo "conda activate failed; ensure env 'graphrag' exists on the remote"; exit 2; }
else
  # Fallback to virtualenv activation
  if [ -f ".venv/bin/activate" ]; then
    echo "Activating .venv..."
    source .venv/bin/activate
  elif [ -f "venv/bin/activate" ]; then
    echo "Activating venv..."
    source venv/bin/activate
  else
    echo "No virtualenv found and conda not available. Create an environment named 'graphrag' or add a venv/.venv in ${REMOTE_DIR}."
    exit 3
  fi
fi

echo "🐍 Запуск скрипта ${REMOTE_SCRIPT}"
# Run shell scripts with bash, python scripts with python3
if [[ "${REMOTE_SCRIPT}" == *.sh ]]; then
  chmod +x "${REMOTE_SCRIPT}" || true
  bash "${REMOTE_SCRIPT}"
else
  python3 "${REMOTE_SCRIPT}"
fi
EOF

