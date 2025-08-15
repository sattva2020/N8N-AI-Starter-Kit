# Zie619 Workflow Import Configuration
# Configuration file for importing workflows from Zie619/n8n-workflows repository

# Repository Information
REPOSITORY_URL = "https://github.com/Zie619/n8n-workflows"
API_URL = "https://api.github.com/repos/Zie619/n8n-workflows"
ZIP_URL = "https://github.com/Zie619/n8n-workflows/archive/refs/heads/main.zip"

# Import Settings
DEFAULT_OUTPUT_DIR = "n8n/workflows/imported"
MAX_CONCURRENT_DOWNLOADS = 5
REQUEST_TIMEOUT = 30
RETRY_ATTEMPTS = 3

# Workflow Categories (based on Zie619's categorization system)
CATEGORIES = {
    "ai_ml": {
        "name": "AI & Machine Learning",
        "keywords": ["OpenAI", "Anthropic", "Hugging Face", "AI", "ML", "GPT", "ChatGPT", "Claude"],
        "description": "Workflows using AI and ML services"
    },
    "messaging": {
        "name": "Communication & Messaging", 
        "keywords": ["Telegram", "Discord", "Slack", "WhatsApp", "Teams", "Mattermost"],
        "description": "Chat bots and messaging automation"
    },
    "email": {
        "name": "Email Automation",
        "keywords": ["Gmail", "Mailjet", "Outlook", "SMTP", "IMAP", "Email"],
        "description": "Email sending and processing workflows"
    },
    "database": {
        "name": "Database Operations",
        "keywords": ["PostgreSQL", "MySQL", "MongoDB", "Redis", "Airtable", "Supabase"],
        "description": "Database integration and data processing"
    },
    "cloud_storage": {
        "name": "Cloud Storage & Files",
        "keywords": ["Google Drive", "Google Sheets", "Dropbox", "OneDrive", "AWS S3"],
        "description": "File management and cloud storage automation"
    },
    "project_management": {
        "name": "Project Management",
        "keywords": ["Jira", "GitHub", "GitLab", "Trello", "Asana", "Monday"],
        "description": "Development and project management tools"
    },
    "social_media": {
        "name": "Social Media",
        "keywords": ["LinkedIn", "Twitter", "Facebook", "Instagram", "YouTube"],
        "description": "Social media automation and management"
    },
    "ecommerce": {
        "name": "E-commerce & Payments",
        "keywords": ["Shopify", "Stripe", "PayPal", "WooCommerce"],
        "description": "Online store and payment processing"
    },
    "forms": {
        "name": "Forms & Surveys",
        "keywords": ["Typeform", "Google Forms", "JotForm"],
        "description": "Form processing and survey automation"
    },
    "development": {
        "name": "Development Tools",
        "keywords": ["Webhook", "HTTP Request", "GraphQL", "API", "REST"],
        "description": "API integration and development workflows"
    },
    "analytics": {
        "name": "Analytics & Reporting",
        "keywords": ["Google Analytics", "Mixpanel", "Amplitude"],
        "description": "Data analytics and reporting workflows"
    },
    "calendar": {
        "name": "Calendar & Scheduling",
        "keywords": ["Google Calendar", "Calendly", "Cal.com"],
        "description": "Calendar and appointment scheduling"
    }
}

# Default Import Filters
DEFAULT_FILTERS = {
    "exclude_test_workflows": True,
    "exclude_example_workflows": True,
    "min_node_count": 2,
    "max_node_count": 100,
    "exclude_inactive": False
}

# Complexity Thresholds
COMPLEXITY_THRESHOLDS = {
    "low": {"min": 1, "max": 5},
    "medium": {"min": 6, "max": 15}, 
    "high": {"min": 16, "max": 999}
}

# Integration Priority (for categorization)
INTEGRATION_PRIORITY = [
    "OpenAI", "Anthropic", "ChatGPT",  # AI gets highest priority
    "Telegram", "Discord", "Slack",    # Messaging
    "GitHub", "GitLab", "Jira",       # Development
    "Google Sheets", "Airtable",      # Data
    "Webhook", "HTTP Request"         # General
]

# Import Presets
IMPORT_PRESETS = {
    "ai_workflows": {
        "name": "AI & Automation Workflows",
        "filters": {
            "category": "ai_ml",
            "min_nodes": 3,
            "complexity": ["medium", "high"]
        },
        "limit": 50
    },
    "business_automation": {
        "name": "Business Process Automation",
        "filters": {
            "category": ["messaging", "email", "project_management"],
            "min_nodes": 5,
            "complexity": ["medium", "high"]
        },
        "limit": 100
    },
    "developer_tools": {
        "name": "Developer & Integration Tools",
        "filters": {
            "category": ["development", "project_management"],
            "keywords": ["webhook", "api", "github", "gitlab"],
            "min_nodes": 3
        },
        "limit": 75
    },
    "data_processing": {
        "name": "Data Processing & Analytics",
        "filters": {
            "category": ["database", "analytics", "cloud_storage"],
            "min_nodes": 4,
            "complexity": ["medium", "high"]
        },
        "limit": 60
    },
    "starter_pack": {
        "name": "Starter Pack (Essential Workflows)",
        "filters": {
            "complexity": ["low", "medium"],
            "min_nodes": 2,
            "max_nodes": 10
        },
        "limit": 25,
        "description": "Simple, well-documented workflows perfect for beginners"
    }
}

# Output Structure
OUTPUT_STRUCTURE = {
    "by_category": True,
    "create_index": True,
    "include_metadata": True,
    "generate_readme": True
}

# File Naming
NAMING_RULES = {
    "sanitize_names": True,
    "max_filename_length": 100,
    "remove_numeric_prefixes": True,
    "use_json_name_when_available": True
}

# Quality Filters
QUALITY_FILTERS = {
    "require_description": False,
    "require_meaningful_name": True,
    "exclude_broken_workflows": True,
    "exclude_test_workflows": True
}
