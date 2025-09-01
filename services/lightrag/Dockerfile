FROM python:3.10-slim

# Minimal image for building and running LightRAG locally for development/testing.
WORKDIR /opt/lightrag

# System deps needed by LightRAG (adjust as required by upstream)
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  git \
  && rm -rf /var/lib/apt/lists/*

# Copy local source (when building from repo clone)
COPY . /opt/lightrag

# Install python deps in editable mode if requirements present
RUN pip install --no-cache-dir pip==23.3.1
RUN if [ -f "pyproject.toml" ] || [ -f "setup.cfg" ] || [ -f "setup.py" ]; then \
  pip install --no-cache-dir -e .[api]; \
  elif [ -f "requirements.txt" ]; then \
  pip install --no-cache-dir -r requirements.txt; \
  fi

EXPOSE 8000

# Default entrypoint: run the LightRAG server (the upstream package provides `lightrag-server`)
CMD ["sh", "-c", "lightrag-server --host 0.0.0.0 --port 8000"]
