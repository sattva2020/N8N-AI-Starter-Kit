# N8N AI Starter Kit Setup Script

## Contents

- [Overview](#overview)
- [Key Improvements](#key-improvements)
- [Operating System Support](#operating-system-support)
- [Features and Capabilities](#features-and-capabilities)
- [System Requirements](#system-requirements)
- [Using the Setup Script](#using-the-setup-script)
- [For Developers](#for-developers)

## Overview

The `scripts/setup.sh` script has been significantly enhanced to provide better reliability, cross-platform compatibility, and improved user experience. The May 2025 update resolved critical issues, added new features, and improved documentation.

## Key Improvements

### 🛠️ Critical Bug Fixes (May 2025)

- Fixed undefined `DC_CMD` variable by moving its definition to script start
- Eliminated duplicate function definitions (`check_port_availability`, `check_cpu_resources`, `check_memory_requirements`)
- Fixed syntax error in `read install_compose` command
- Properly ordered function declarations for consistent execution flow
- Escaped `$` symbols in Traefik password hash to prevent environment variable expansion issues
- Reorganized Docker network definitions to eliminate conflicts

### 🚀 New Scripts and Automated Fixes

- `scripts/fix-and-start.sh` - automatically applies all fixes and starts the system
- `scripts/fix-env-vars.sh` - generates missing environment variables
- `scripts/start-with-limited-parallelism.sh` - starts system with parallelism limits
- Equivalent scripts for Windows (`*.ps1`)

## Features and Capabilities

### 🖥️ Operating System Detection

- Supports Ubuntu, Debian, CentOS, RHEL, Fedora, and macOS
- Automatically selects appropriate installation commands based on OS
- Color-coded and informative messages for better user experience

### 🐳 Docker and Docker Compose Management

- Automatic detection and installation of Docker and Docker Compose
- Support for both new (`docker compose`) and legacy (`docker-compose`) syntax
- Docker group membership verification and automatic user addition

### 🛡️ Error Handling and Input Validation

- Domain name and email validation using regular expressions
- Alternative password hash generation methods for error recovery
- Detailed error messages with troubleshooting guidance
- Automatic backup of existing configurations before overwriting
- Port availability check for 80 and 443 (Traefik and SSL certificates)

### 🎮 GPU Detection and Configuration

- Automatic detection of NVIDIA and AMD GPUs
- Verification of nvidia-container-toolkit for Docker GPU support
- Launch profile recommendations based on hardware

## System Requirements

### 💾 Memory:

- Less than 4GB: Performance warning issued
- 4-8GB: Suitable for basic tasks
- Over 8GB: Optimal for all services

### 💻 CPU:

- Less than 2 cores: Limited performance warning
- 2-4 cores: Suitable for basic tasks
- Over 4 cores: Optimal for all services

### 💿 Disk Space:

- Less than 10GB: Space shortage warning
- 10-20GB: Sufficient for initial setup
- Over 20GB: Recommended for long-term use

## Using the Setup Script

### Basic Usage:

```bash
bash scripts/setup.sh
```

### Post-install: applying bulk credentials

After the setup script has generated your `.env` and you've started the stack (for example `docker compose up -d` or `./start.sh`), n8n UI may take a short while to become available. To apply bulk credentials safely:

1. Create a personal/admin token in the n8n UI and keep it secret (see `docs/credentials.md`).
2. Verify n8n is reachable (default: `http://localhost:5678`).
3. Run a dry-run to validate payloads (no changes made):

```bash
./scripts/create_n8n_credential.sh --dry-run --token "<YOUR_N8N_ADMIN_TOKEN>" \
   --bulk-file config/samples/credentials-bulk.json --n8n-url http://localhost:5678
```

4. If the dry-run output looks good, run the real import:

```bash
./scripts/create_n8n_credential.sh --token "<YOUR_N8N_ADMIN_TOKEN>" \
   --bulk-file config/samples/credentials-bulk.json --n8n-url http://localhost:5678
```

For CI use, read the token from your secret manager and export it into the environment instead of checking it into files.

### Installation Process:

1. OS detection and version verification
2. Docker presence check and optional installation
3. Docker Compose verification and setup if needed
4. Basic information collection (domain name, email)
5. Secure password and key generation
6. `.env` file creation
7. GPU detection and system resource verification
8. Data directory structure creation
9. Profile-specific launch instructions

## Operating System Support

### Linux:

- Ubuntu (all recent versions)
- Debian (all recent versions)
- CentOS/RHEL (7 and above)
- Fedora (all recent versions)

### macOS:

- Docker Desktop installation instructions provided
- Manual Docker installation required, but script supports pre-installed Docker

## For Developers

### Testing Recommendations:

1. **Cross-Platform Testing**:

   - Ubuntu 22.04 and 24.04
   - Debian 11 and 12
   - CentOS/RHEL 8 and 9
   - Fedora 35+
   - macOS environments

2. **Future Enhancements**:
   - Non-interactive mode for CI/CD pipelines
   - Enhanced GPU detection and configuration
   - Backup restoration capabilities
   - Component update system integration
