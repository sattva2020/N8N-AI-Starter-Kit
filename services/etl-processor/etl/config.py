"""
ETL Configuration
"""

import os
from typing import Optional
from pydantic import Field
from pydantic_settings import BaseSettings

class ETLConfig(BaseSettings):
    """ETL configuration settings"""
    
    # ClickHouse settings
    clickhouse_host: str = Field(default="clickhouse", env="CLICKHOUSE_HOST")
    clickhouse_port: int = Field(default=9000, env="CLICKHOUSE_PORT")
    clickhouse_user: str = Field(default="analytics_user", env="CLICKHOUSE_USER")
    clickhouse_password: str = Field(default="clickhouse_pass_2024", env="CLICKHOUSE_PASSWORD")
    clickhouse_database: str = Field(default="n8n_analytics", env="CLICKHOUSE_DATABASE")
    
    # PostgreSQL settings
    postgres_host: str = Field(default="n8n-postgres", env="POSTGRES_HOST")
    postgres_port: int = Field(default=5432, env="POSTGRES_PORT")
    postgres_user: str = Field(default="root", env="POSTGRES_USER")
    postgres_password: str = Field(default="password", env="POSTGRES_PASSWORD")
    postgres_database: str = Field(default="n8n", env="POSTGRES_DATABASE")
    
    # N8N API settings
    n8n_api_url: str = Field(default="http://n8n:5678", env="N8N_API_URL")
    n8n_api_key: Optional[str] = Field(default=None, env="N8N_API_KEY")
    
    # Redis settings
    redis_url: str = Field(default="redis://redis:6379/2", env="REDIS_URL")
    
    # ETL settings
    etl_batch_size: int = Field(default=1000, env="ETL_BATCH_SIZE")
    etl_max_retries: int = Field(default=3, env="ETL_MAX_RETRIES")
    etl_retry_delay: int = Field(default=60, env="ETL_RETRY_DELAY")
    
    # Logging
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    log_file: str = Field(default="/app/logs/etl.log", env="LOG_FILE")
    
    class Config:
        env_file = ".env"
        case_sensitive = False
