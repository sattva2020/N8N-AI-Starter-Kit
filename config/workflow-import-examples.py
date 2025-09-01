#!/usr/bin/env python3
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
