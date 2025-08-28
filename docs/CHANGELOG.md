### chore(traefik): switch to ACME HTTP-01 and add HTTP router for n8n

- ACME changed from TLS-ALPN-01 to HTTP-01 with entrypoint `web`.
- Added HTTP router for `n8n` with `https-redirect@file` middleware.
- Improves reliability of certificate issuance and enforces HTTP→HTTPS redirect.

# Changelog

## [Unreleased]

### Added
- Added credentials for Ollama, ClickHouse, Elasticsearch, and Prometheus to the bulk import file (`data/credentials-bulk.json`).

### Fixed
- Fixed a bug in `scripts/create_n8n_credential.sh` where bulk credential creation with `--bulk-file` was failing due to incorrect argument validation order.
- Fixed jq empty-string check in `scripts/create_n8n_credential.sh` causing a bash parse error during schema validation.

### Removed
- Completely removed all references to MinIO (S3) from the project, including from credential creation scripts and documentation.