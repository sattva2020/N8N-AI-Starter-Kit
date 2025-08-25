#!/usr/bin/env python3
"""
Setup script for Zie619 workflow import functionality.
Installs dependencies and configures the import system.
"""

import subprocess
import sys
import os
from pathlib import Path

def install_package(package):
    """Install Python package using pip."""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        return True
    except subprocess.CalledProcessError:
        return False

def check_package(package):
    """Check if package is installed."""
    try:
        __import__(package)
        return True
    except ImportError:
        return False

def setup_dependencies():
    """Install required dependencies."""
    print("📦 Setting up dependencies for Zie619 workflow import...")
    
    dependencies = [
        "requests",
        "inquirer", 
        "sqlite3"  # Usually built-in, but check anyway
    ]
    
    for dep in dependencies:
        if dep == "sqlite3":
            # sqlite3 is usually built-in
            continue
            
        print(f"Checking {dep}...")
        if check_package(dep):
            print(f"✅ {dep} is already installed")
        else:
            print(f"📥 Installing {dep}...")
            if install_package(dep):
                print(f"✅ {dep} installed successfully")
            else:
                print(f"❌ Failed to install {dep}")
                return False
    
    return True

def create_directories():
    """Create necessary directories."""
    print("📁 Creating directories...")
    
    directories = [
        "n8n/workflows/imported",
        "n8n/workflows/imported/ai_ml",
        "n8n/workflows/imported/messaging", 
        "n8n/workflows/imported/email",
        "n8n/workflows/imported/database",
        "n8n/workflows/imported/cloud_storage",
        "n8n/workflows/imported/development",
        "n8n/workflows/imported/general",
        "config",
        "logs"
    ]
    
    for directory in directories:
        dir_path = Path(directory)
        dir_path.mkdir(parents=True, exist_ok=True)
        print(f"✅ Created: {directory}")

def create_requirements_file():
    """Create requirements.txt for workflow import."""
    requirements_content = """# Zie619 Workflow Import Dependencies
requests>=2.25.0
inquirer>=2.7.0
pathlib>=1.0.0
sqlite3
"""
    
    requirements_path = Path("scripts/requirements-workflow-import.txt")
    with open(requirements_path, 'w') as f:
        f.write(requirements_content)
    
    print(f"✅ Created: {requirements_path}")

def create_example_config():
    """Create example configuration file."""
    example_config = """#!/usr/bin/env python3
# Example configuration for Zie619 workflow import

# Quick import presets
QUICK_PRESETS = {
    "ai_starter": {
        "name": "AI Starter Pack",
        "filters": {"category": "ai_ml", "complexity": ["low", "medium"]},
        "limit": 20
    },
    "business_essentials": {
        "name": "Business Essentials", 
        "filters": {"category": ["messaging", "email"], "min_nodes": 3},
        "limit": 30
    },
    "developer_tools": {
        "name": "Developer Tools",
        "filters": {"category": "development", "keywords": ["webhook", "api"]},
        "limit": 25
    }
}

# Default settings
DEFAULT_OUTPUT_DIR = "n8n/workflows/imported"
DEFAULT_N8N_URL = "http://localhost:5678"
DEFAULT_IMPORT_LIMIT = 50
"""
    
    config_path = Path("config/workflow-import-examples.py")
    with open(config_path, 'w') as f:
        f.write(example_config)
    
    print(f"✅ Created: {config_path}")

def create_usage_guide():
    """Create usage guide for the import system."""
    guide_content = """# 🔄 Zie619 Workflow Import Guide

## Quick Start

### 1. Interactive Import (Recommended)
```bash
python scripts/workflow-import-cli.py
```

### 2. Direct Import with Preset
```bash
# Import AI workflows
python scripts/import-zie619-workflows.py --category ai_ml --limit 25

# Import business automation workflows  
python scripts/import-zie619-workflows.py --category messaging --min-nodes 3 --limit 30

# Import developer tools
python scripts/import-zie619-workflows.py --keywords webhook api github --limit 20
```

### 3. Import to N8N
```bash
# Import downloaded workflows into N8N instance
python scripts/import-to-n8n.py n8n/workflows/imported --n8n-url http://localhost:5678
```

## Available Categories
- `ai_ml` - AI & Machine Learning workflows
- `messaging` - Chat bots and messaging automation
- `email` - Email automation workflows
- `database` - Database operations and data processing
- `cloud_storage` - File management and cloud storage
- `project_management` - Development and project management
- `development` - Webhooks, APIs, and developer tools

## Filter Options
- `--category` - Filter by workflow category
- `--complexity` - Filter by complexity (low/medium/high)
- `--min-nodes` - Minimum number of nodes
- `--max-nodes` - Maximum number of nodes
- `--keywords` - Search keywords in workflow names
- `--limit` - Maximum workflows to import

## Examples

### Import AI Workflows for Beginners
```bash
python scripts/import-zie619-workflows.py \\
  --category ai_ml \\
  --complexity low medium \\
  --max-nodes 10 \\
  --limit 15
```

### Import Advanced Business Automation
```bash
python scripts/import-zie619-workflows.py \\
  --category messaging email \\
  --min-nodes 5 \\
  --keywords automation notification \\
  --limit 40
```

### Import Developer Integration Tools
```bash
python scripts/import-zie619-workflows.py \\
  --category development \\
  --keywords webhook api github gitlab \\
  --min-nodes 3 \\
  --limit 25
```

## Output Structure
```
n8n/workflows/imported/
├── ai_ml/
│   ├── ChatGPT_Document_Analysis.json
│   ├── OpenAI_Content_Generator.json
│   └── ...
├── messaging/
│   ├── Telegram_Bot_Automation.json
│   ├── Discord_Notification_System.json
│   └── ...
└── development/
    ├── GitHub_Issue_Tracker.json
    ├── Webhook_Data_Processor.json
    └── ...
```

## Integration with N8N

### Import via API (Recommended)
```bash
python scripts/import-to-n8n.py n8n/workflows/imported
```

### Import via CLI (Fallback)
```bash
python scripts/import-to-n8n.py n8n/workflows/imported --use-cli
```

### Filter during N8N import
```bash
python scripts/import-to-n8n.py n8n/workflows/imported \\
  --min-nodes 3 \\
  --complexity medium high \\
  --keywords automation
```

## Troubleshooting

### N8N Connection Issues
1. Ensure N8N is running: `docker-compose up -d`
2. Check URL: `http://localhost:5678`
3. Use CLI import as fallback: `--use-cli`

### Import Errors
1. Check internet connection for repository download
2. Verify disk space for workflow files
3. Check permissions on output directory

### Missing Dependencies
```bash
pip install -r scripts/requirements-workflow-import.txt
```

## Repository Information
- **Source**: https://github.com/Zie619/n8n-workflows
- **Total workflows**: 2,053+ automation workflows
- **Categories**: 12 main categories with 365+ integrations
- **Quality**: Professionally organized with meaningful names
"""
    
    guide_path = Path("docs/WORKFLOW_IMPORT_GUIDE.md")
    with open(guide_path, 'w') as f:
        f.write(guide_content)
    
    print(f"✅ Created: {guide_path}")

def make_scripts_executable():
    """Make Python scripts executable on Unix systems."""
    if os.name != 'nt':  # Not Windows
        scripts = [
            "scripts/import-zie619-workflows.py",
            "scripts/import-to-n8n.py", 
            "scripts/workflow-import-cli.py"
        ]
        
        for script in scripts:
            script_path = Path(script)
            if script_path.exists():
                os.chmod(script_path, 0o755)
                print(f"✅ Made executable: {script}")

def verify_setup():
    """Verify that setup completed successfully."""
    print("\n🔍 Verifying setup...")
    
    # Check scripts exist
    required_scripts = [
        "scripts/import-zie619-workflows.py",
        "scripts/import-to-n8n.py",
        "scripts/workflow-import-cli.py"
    ]
    
    for script in required_scripts:
        if Path(script).exists():
            print(f"✅ {script}")
        else:
            print(f"❌ {script} - Missing!")
            return False
    
    # Check directories
    if Path("n8n/workflows/imported").exists():
        print("✅ Output directories created")
    else:
        print("❌ Output directories - Missing!")
        return False
    
    # Check dependencies
    try:
        import requests
        print("✅ requests package")
    except ImportError:
        print("❌ requests package - Not installed!")
        return False
    
    return True

def main():
    """Main setup function."""
    print("🚀 Zie619 Workflow Import Setup")
    print("=" * 50)
    
    success = True
    
    # Install dependencies
    if not setup_dependencies():
        success = False
    
    # Create directories
    create_directories()
    
    # Create configuration files
    create_requirements_file()
    create_example_config()
    create_usage_guide()
    
    # Make scripts executable
    make_scripts_executable()
    
    # Verify setup
    if not verify_setup():
        success = False
    
    print("\n" + "=" * 50)
    if success:
        print("✅ Setup completed successfully!")
        print("\n🚀 Quick Start:")
        print("python scripts/workflow-import-cli.py")
        print("\n📚 Documentation:")
        print("docs/WORKFLOW_IMPORT_GUIDE.md")
    else:
        print("❌ Setup completed with errors!")
        print("Please check the error messages above.")
    
    return success

if __name__ == "__main__":
    if main():
        sys.exit(0)
    else:
        sys.exit(1)
