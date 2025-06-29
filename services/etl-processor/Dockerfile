FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
  gcc \
  g++ \
  curl \
  && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY services/etl-processor/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY services/etl-processor/ .

# Create directories
RUN mkdir -p /app/logs /app/data /app/config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Expose port
EXPOSE 8080

# Run the application
CMD ["python", "main.py"]
