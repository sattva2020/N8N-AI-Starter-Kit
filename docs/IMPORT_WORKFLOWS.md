Import workflows into n8n via REST API

This document describes `scripts/import_workflows_to_n8n.sh` — a small helper
that imports workflow JSON files (n8n export format) into a running n8n
instance using the REST API.

Usage:

```bash
./scripts/import_workflows_to_n8n.sh --dir ./n8n/workflows/imported --token "$N8N_ADMIN_TOKEN" --n8n-url http://localhost:5678 --dry-run
```

Behavior:
- For each `*.json` file in the directory:
  - If the JSON contains an `id` field, the script attempts a PUT to `/rest/workflows/{id}`.
  - Otherwise it POSTs to `/rest/workflows` to create a new workflow.
  - After successful create/update the script attempts to activate the workflow.

Security and notes:
- Keep `N8N_ADMIN_TOKEN` secret. Store it in `.env.local` or a secret manager.
- Use `--dry-run` on first invocation to validate what will be changed.
