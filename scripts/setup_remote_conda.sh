#!/usr/bin/env bash
set -euo pipefail

REMOTE_DIR="/opt/graphrag"
MINICONDA_PREFIX="/root/miniconda"

cd "${REMOTE_DIR}"

# Install Miniconda if missing
if [ ! -x "${MINICONDA_PREFIX}/bin/conda" ]; then
  echo "Installing Miniconda to ${MINICONDA_PREFIX}..."
  bash ./miniconda.sh -b -p "${MINICONDA_PREFIX}"
fi

export PATH="${MINICONDA_PREFIX}/bin:$PATH"

# Accept ToS for default channels (non-interactive)
if command -v conda >/dev/null 2>&1; then
  echo "Conda version: $(conda --version)"
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true
else
  echo "conda not found after installation" >&2
  exit 2
fi

# Create environment with Python 3.12 and faiss-cpu from conda-forge
if ! conda env list | grep -q "^graphrag"; then
  echo "Creating conda env 'graphrag' with python=3.12 and faiss-cpu..."
  conda create -n graphrag python=3.12 faiss-cpu -c conda-forge -y
else
  echo "Conda env 'graphrag' already exists"
fi

# Install package and runtime deps inside env
echo "Installing Python package and runtime deps into 'graphrag'..."
conda run -n graphrag pip install -e "${REMOTE_DIR}"
conda run -n graphrag pip install ollama pandas devtools tiktoken || true

echo "Setup complete. Running test..."
conda run -n graphrag python "${REMOTE_DIR}/test_graphrag_with_ollama.py"

echo "DONE"
