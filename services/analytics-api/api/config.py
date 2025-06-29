"""
Analytics API Configuration
"""

import os
from typing import List, Union
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class APIConfig(BaseSettings):
    """Analytics API configuration settings"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        env_parse_none_str="",
        # Don't automatically parse complex types as JSON
        env_ignore_empty=True
    )
    
    # ClickHouse settings
    clickhouse_host: str = Field(default="clickhouse", env="CLICKHOUSE_HOST")
    clickhouse_port: int = Field(default=9000, env="CLICKHOUSE_PORT")
    clickhouse_user: str = Field(default="analytics_user", env="CLICKHOUSE_USER")
    clickhouse_password: str = Field(default="clickhouse_pass_2024", env="CLICKHOUSE_PASSWORD")
    clickhouse_database: str = Field(default="n8n_analytics", env="CLICKHOUSE_DATABASE")
    
    # Redis settings
    redis_url: str = Field(default="redis://redis:6379/2", env="REDIS_URL")
    
    # API settings
    require_api_key: bool = Field(default=False, env="REQUIRE_API_KEY")
    
    # CORS settings - использовать жёсткие значения для тестирования
    @property
    def cors_origins(self) -> List[str]:
        """Возвращает список разрешённых CORS origins"""
        return ["http://localhost:3000", "http://localhost:8088", "*"]
    
    @property
    def api_keys(self) -> List[str]:
        """Возвращает список API ключей"""
        return []  # Пустой список - авторизация отключена
    
    # Cache settings
    cache_ttl_default: int = Field(default=600, env="CACHE_TTL_DEFAULT")  # 10 minutes
    cache_ttl_long: int = Field(default=3600, env="CACHE_TTL_LONG")  # 1 hour
    cache_ttl_short: int = Field(default=300, env="CACHE_TTL_SHORT")  # 5 minutes
    
    # Rate limiting
    rate_limit_requests: int = Field(default=1000, env="RATE_LIMIT_REQUESTS")
    rate_limit_window: int = Field(default=3600, env="RATE_LIMIT_WINDOW")  # 1 hour
    
    # Logging
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    log_file: str = Field(default="/app/logs/analytics-api.log", env="LOG_FILE")
    
    # Query limits
    max_query_range_days: int = Field(default=90, env="MAX_QUERY_RANGE_DAYS")
    max_results_per_query: int = Field(default=10000, env="MAX_RESULTS_PER_QUERY")
