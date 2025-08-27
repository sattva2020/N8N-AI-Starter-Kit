# Changelog

## [Unreleased]

### Fixed
- Fixed a bug in `scripts/create_n8n_credential.sh` where bulk credential creation with `--bulk-file` was failing due to incorrect argument validation order.

### Removed
- Completely removed all references to MinIO (S3) from the project, including from credential creation scripts and documentation.
