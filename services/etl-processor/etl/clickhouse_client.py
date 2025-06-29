"""
ClickHouse client for analytics data
"""

import asyncio
import time
from datetime import datetime
from typing import List, Dict, Any, Optional
import structlog
from clickhouse_driver import Client as SyncClient
from clickhouse_driver.errors import Error as ClickHouseError

logger = structlog.get_logger(__name__)

class ClickHouseClient:
    """Async ClickHouse client wrapper"""
    
    def __init__(self, config):
        self.config = config
        self.client = None
        self._initialized = False

    async def initialize(self):
        """Initialize ClickHouse connection with retry mechanism"""
        max_retries = 5
        retry_delay = 2  # seconds
        
        for attempt in range(max_retries):
            try:
                # Create sync client (clickhouse-driver doesn't have native async support)
                self.client = SyncClient(
                    host=self.config.clickhouse_host,
                    port=self.config.clickhouse_port,
                    user=self.config.clickhouse_user,
                    password=self.config.clickhouse_password,
                    database=self.config.clickhouse_database,
                    settings={
                        'use_numpy': True,
                        'max_execution_time': 300,
                        'send_receive_timeout': 300,
                    }
                )
                
                # Set initialized flag first
                self._initialized = True
                
                # Test connection
                await self.execute("SELECT 1")
                
                logger.info("ClickHouse client initialized", 
                           host=self.config.clickhouse_host,
                           database=self.config.clickhouse_database,
                           attempt=attempt + 1)
                return
                
            except Exception as e:
                self._initialized = False
                logger.warning(f"ClickHouse connection attempt {attempt + 1} failed", 
                             error=str(e),
                             host=self.config.clickhouse_host)
                
                if attempt == max_retries - 1:
                    logger.error("Failed to initialize ClickHouse client", error=str(e))
                    raise
                
                # Wait before retry
                await asyncio.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff

    async def execute(self, query: str, params: Optional[Dict] = None) -> List[Any]:
        """Execute query asynchronously"""
        if not self._initialized:
            raise RuntimeError("ClickHouse client not initialized")
        
        try:
            # Run in executor to make it async
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None, 
                lambda: self.client.execute(query, params or {})
            )
            return result
            
        except ClickHouseError as e:
            logger.error("ClickHouse query failed", query=query, error=str(e))
            raise
        except Exception as e:
            logger.error("Unexpected error executing ClickHouse query", query=query, error=str(e))
            raise

    async def insert_data(self, table: str, data: List[Dict[str, Any]]) -> int:
        """Insert data into table"""
        if not data:
            return 0
            
        try:
            # Convert dict data to tuples for bulk insert
            if data:
                columns = list(data[0].keys())
                values = [tuple(row[col] for col in columns) for row in data]
                
                query = f"INSERT INTO {table} ({', '.join(columns)}) VALUES"
                
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(
                    None,
                    lambda: self.client.execute(query, values)
                )
                
                logger.info(f"Inserted data into {table}", records=len(data))
                return len(data)
                
        except Exception as e:
            logger.error(f"Failed to insert data into {table}", error=str(e))
            raise

    async def insert_workflow_executions(self, executions: List[Dict[str, Any]]) -> int:
        """Insert workflow executions data"""
        if not executions:
            return 0
            
        processed_data = []
        for execution in executions:
            processed_data.append({
                'id': execution.get('id', ''),
                'workflow_id': execution.get('workflowId', ''),
                'workflow_name': execution.get('workflowData', {}).get('name', ''),
                'status': execution.get('status', ''),
                'mode': execution.get('mode', ''),
                'started_at': execution.get('startedAt', datetime.utcnow()),
                'finished_at': execution.get('finishedAt', datetime.utcnow()),
                'duration_ms': self._calculate_duration_ms(
                    execution.get('startedAt'),
                    execution.get('finishedAt')
                ),
                'data_processed': len(execution.get('data', {})),
                'created_at': datetime.utcnow()
            })
        
        return await self.insert_data('workflow_executions', processed_data)

    async def insert_workflow_metrics(self, metrics: List[Dict[str, Any]]) -> int:
        """Insert workflow metrics data"""
        if not metrics:
            return 0
            
        return await self.insert_data('workflow_metrics', metrics)

    async def insert_node_performance(self, performance_data: List[Dict[str, Any]]) -> int:
        """Insert node performance data"""
        if not performance_data:
            return 0
            
        return await self.insert_data('node_performance', performance_data)

    async def insert_error_analysis(self, errors: List[Dict[str, Any]]) -> int:
        """Insert error analysis data"""
        if not errors:
            return 0
            
        return await self.insert_data('error_analysis', errors)

    async def get_last_processed_timestamp(self, table: str, timestamp_column: str = 'created_at') -> Optional[datetime]:
        """Get last processed timestamp from table"""
        try:
            query = f"SELECT max({timestamp_column}) FROM {table}"
            result = await self.execute(query)
            
            if result and result[0] and result[0][0]:
                return result[0][0]
            return None
            
        except Exception as e:
            logger.error(f"Failed to get last timestamp from {table}", error=str(e))
            return None

    async def optimize_tables(self):
        """Optimize ClickHouse tables"""
        tables = ['workflow_executions', 'workflow_metrics', 'node_performance', 'error_analysis']
        
        for table in tables:
            try:
                await self.execute(f"OPTIMIZE TABLE {table}")
                logger.info(f"Optimized table: {table}")
            except Exception as e:
                logger.warning(f"Failed to optimize table {table}", error=str(e))

    def _calculate_duration_ms(self, started_at: Optional[datetime], finished_at: Optional[datetime]) -> int:
        """Calculate duration in milliseconds"""
        if not started_at or not finished_at:
            return 0
        
        try:
            if isinstance(started_at, str):
                started_at = datetime.fromisoformat(started_at.replace('Z', '+00:00'))
            if isinstance(finished_at, str):
                finished_at = datetime.fromisoformat(finished_at.replace('Z', '+00:00'))
            
            delta = finished_at - started_at
            return int(delta.total_seconds() * 1000)
        except Exception:
            return 0

    async def close(self):
        """Close ClickHouse connection"""
        if self.client:
            try:
                # ClickHouse driver doesn't need explicit close
                self.client = None
                self._initialized = False
                logger.info("ClickHouse client closed")
            except Exception as e:
                logger.error("Error closing ClickHouse client", error=str(e))
