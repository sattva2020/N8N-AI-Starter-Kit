"""
ETL Data Processors
"""

from datetime import datetime, timedelta
from typing import List, Dict, Any
import structlog

logger = structlog.get_logger(__name__)

class WorkflowExecutionProcessor:
    """Process workflow execution data"""
    
    def __init__(self, postgres_client, clickhouse_client):
        self.postgres = postgres_client
        self.clickhouse = clickhouse_client

    async def process_recent_executions(self, since: datetime) -> int:
        """Process recent workflow executions"""
        try:
            # Get recent executions from PostgreSQL
            executions = await self.postgres.get_recent_executions(since)
            
            if not executions:
                return 0
            
            # Insert into ClickHouse
            return await self.clickhouse.insert_workflow_executions(executions)
            
        except Exception as e:
            logger.error("Failed to process recent executions", error=str(e))
            raise

class WorkflowMetricsProcessor:
    """Process workflow metrics"""
    
    def __init__(self, postgres_client, clickhouse_client):
        self.postgres = postgres_client
        self.clickhouse = clickhouse_client

    async def process_daily_metrics(self) -> int:
        """Process daily workflow metrics"""
        try:
            # Process metrics for yesterday and today
            today = datetime.utcnow().date()
            yesterday = today - timedelta(days=1)
            
            total_records = 0
            
            for date in [yesterday, today]:
                date_dt = datetime.combine(date, datetime.min.time())
                metrics = await self.postgres.get_workflow_metrics(date_dt)
                
                if metrics:
                    records = await self.clickhouse.insert_workflow_metrics(metrics)
                    total_records += records
                    logger.info(f"Processed metrics for {date}", records=records)
            
            return total_records
            
        except Exception as e:
            logger.error("Failed to process workflow metrics", error=str(e))
            raise

class NodePerformanceProcessor:
    """Process node performance data"""
    
    def __init__(self, postgres_client, clickhouse_client):
        self.postgres = postgres_client
        self.clickhouse = clickhouse_client

    async def process_node_performance(self, since: datetime) -> int:
        """Process node performance data"""
        try:
            # Get node performance data from PostgreSQL
            performance_data = await self.postgres.get_node_performance(since)
            
            if not performance_data:
                return 0
            
            # Insert into ClickHouse
            return await self.clickhouse.insert_node_performance(performance_data)
            
        except Exception as e:
            logger.error("Failed to process node performance", error=str(e))
            raise

class ErrorAnalysisProcessor:
    """Process error analysis data"""
    
    def __init__(self, postgres_client, clickhouse_client):
        self.postgres = postgres_client
        self.clickhouse = clickhouse_client

    async def process_errors(self, since: datetime) -> int:
        """Process error analysis data"""
        try:
            # Get error data from PostgreSQL
            errors = await self.postgres.get_error_analysis(since)
            
            if not errors:
                return 0
            
            # Insert into ClickHouse
            return await self.clickhouse.insert_error_analysis(errors)
            
        except Exception as e:
            logger.error("Failed to process error analysis", error=str(e))
            raise
