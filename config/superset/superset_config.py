import os
from datetime import timedelta
from typing import Optional

# Flask app configuration
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'superset_secret_key_2024')
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# Database configuration
SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL', 'postgresql://superset:postgres@postgres:5432/superset')
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_ENGINE_OPTIONS = {
    'pool_pre_ping': True,
    'pool_recycle': 300,
    'pool_timeout': 20,
    'max_overflow': 0,
}

# Redis configuration
REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/1')

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_URL': REDIS_URL,
}

DATA_CACHE_CONFIG = CACHE_CONFIG

# Results backend configuration
RESULTS_BACKEND = {
    'cache_type': 'RedisCache',
    'cache_default_timeout': 86400,  # 1 day
    'cache_key_prefix': 'superset_results_',
    'cache_redis_url': REDIS_URL,
}

# Feature flags
FEATURE_FLAGS = {
    'ALERT_REPORTS': True,
    'DASHBOARD_FILTERS_EXPERIMENTAL': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DYNAMIC_PLUGINS': True,
    'ENABLE_TEMPLATE_PROCESSING': True,
    'LISTVIEWS_DEFAULT_CARD_VIEW': True,
    'THUMBNAILS': True,
    'THUMBNAILS_SQLA_LISTENERS': True,
    'VERSIONED_EXPORT': True,
    'GLOBAL_ASYNC_QUERIES': True,
    'DASHBOARD_RBAC': True,
}

# Email configuration (optional)
SMTP_HOST = os.environ.get('SMTP_HOST', 'localhost')
SMTP_STARTTLS = True
SMTP_SSL = False
SMTP_USER = os.environ.get('SMTP_USER', 'superset')
SMTP_PORT = int(os.environ.get('SMTP_PORT', '587'))
SMTP_PASSWORD = os.environ.get('SMTP_PASSWORD', '')
SMTP_MAIL_FROM = os.environ.get('SMTP_MAIL_FROM', 'superset@n8n-analytics.local')

# Security
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    'force_https': False,
    'content_security_policy': None,
}

# CORS
ENABLE_CORS = True
CORS_OPTIONS = {
    'supports_credentials': True,
    'allow_headers': ['*'],
    'resources': ['*'],
    'origins': ['http://localhost:3000', 'http://localhost:8088']
}

# Language
LANGUAGES = {
    'en': {'flag': 'us', 'name': 'English'},
    'ru': {'flag': 'ru', 'name': 'Russian'},
}

# Query timeout
SUPERSET_WEBSERVER_TIMEOUT = 300
SQLLAB_TIMEOUT = 300
SQLLAB_ASYNC_TIME_LIMIT_SEC = 600

# CSV export
CSV_EXPORT = {
    'encoding': 'utf-8',
}

# Row limit
ROW_LIMIT = 50000
VIZ_ROW_LIMIT = 10000

# SQL Lab configuration
SQLLAB_CTAS_NO_LIMIT = True
CUSTOM_SECURITY_MANAGER = None

# Dashboard and chart configuration
DASHBOARD_AUTO_REFRESH_MODE = "fetch"
DASHBOARD_AUTO_REFRESH_INTERVALS = [
    [0, "Don't refresh"],
    [10, "10 seconds"],
    [30, "30 seconds"],
    [60, "1 minute"],
    [300, "5 minutes"],
    [1800, "30 minutes"],
    [3600, "1 hour"],
]

# Logging
ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = 'INFO'
FILENAME = os.path.join('/app/logs', 'superset.log')

# Async query configuration
GLOBAL_ASYNC_QUERIES_TRANSPORT = "polling"
GLOBAL_ASYNC_QUERIES_POLLING_DELAY = 500

# Custom CSS
EXTRA_CATEGORICAL_COLOR_SCHEMES = [
    {
        'id': 'n8n_colors',
        'description': 'N8N Brand Colors',
        'colors': ['#FF6D5A', '#007ACC', '#52C41A', '#FAAD14', '#F759AB', '#722ED1']
    }
]

# Default database connections
DATABASES_TO_CREATE = [
    {
        'database_name': 'ClickHouse Analytics',
        'sqlalchemy_uri': 'clickhouse+native://analytics_user:clickhouse_pass_2024@clickhouse:9000/n8n_analytics',
        'expose_in_sqllab': True,
        'allow_ctas': True,
        'allow_cvas': True,
        'allow_dml': False,
    }
]

# Custom configuration for N8N Analytics
APP_NAME = "N8N Analytics Dashboard"
APP_ICON = "/static/assets/images/superset-logo-horiz.png"
FAVICONS = [{"href": "/static/assets/images/favicon.png"}]

# Security settings
PREVENT_UNSAFE_DB_CONNECTIONS = False
SQLALCHEMY_EXAMPLES_URI = None

# Webdriver configuration for thumbnails
WEBDRIVER_BASEURL = "http://superset:8088/"
WEBDRIVER_BASEURL_USER_FRIENDLY = "http://localhost:8088/"

# Custom roles
CUSTOM_ROLES = {
    'N8N_Analytics_Admin': [
        ['can_read', 'Dataset'],
        ['can_write', 'Dataset'], 
        ['can_read', 'Chart'],
        ['can_write', 'Chart'],
        ['can_read', 'Dashboard'],
        ['can_write', 'Dashboard'],
        ['can_read', 'Database'],
        ['can_write', 'Database'],
    ],
    'N8N_Analytics_Viewer': [
        ['can_read', 'Dataset'],
        ['can_read', 'Chart'],
        ['can_read', 'Dashboard'],
        ['can_read', 'Database'],
    ]
}
