#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Waiting for n8n to be available ---"

# Loop until n8n is reachable
# This is a simple check. A more robust solution might use `nc` or `curl` if available,
# or check for a specific health endpoint if n8n provides one.
# We assume n8n is on the default port 5678. The hostname 'n8n' is resolved by Docker's internal DNS.
while !</dev/tcp/n8n/5678; do
    echo "n8n is unavailable - sleeping"
    sleep 5
done

echo "--- n8n is up, starting workflow import ---"

# Execute the main Python script
python import-workflows.py

echo "--- Import script finished ---"
