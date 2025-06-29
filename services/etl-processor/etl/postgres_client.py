"""
PostgreSQL client for N8N data access
"""

import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import structlog
import asyncpg
from asyncpg import Connection, Pool

logger = structlog.get_logger(__name__)

class PostgresClient:
    """Async PostgreSQL client for N8N database"""
    
    def __init__(self, config):
        self.config = config
        self.pool: Optional[Pool] = None
        self._initialized = False

    async def initialize(self):
        """Initialize PostgreSQL connection pool"""
        try:
            connection_string = (
                f"postgresql://{self.config.postgres_user}:{self.config.postgres_password}"
                f"@{self.config.postgres_host}:{self.config.postgres_port}/{self.config.postgres_database}"
            )
            
            self.pool = await asyncpg.create_pool(
                connection_string,
                min_size=1,
                max_size=10,
                command_timeout=60,
                server_settings={
                    'application_name': 'n8n-etl-processor',
                }
            )
            
            # Test connection
            async with self.pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            
            self._initialized = True
            logger.info("PostgreSQL client initialized",
                       host=self.config.postgres_host,
                       database=self.config.postgres_database)
            
        except Exception as e:
            logger.error("Failed to initialize PostgreSQL client", error=str(e))
            raise

    async def get_recent_executions(self, since: datetime) -> List[Dict[str, Any]]:
        """Get recent workflow executions"""
        if not self._initialized:
            raise RuntimeError("PostgreSQL client not initialized")
        
        query = """
            SELECT 
                e.id,
                e."workflowId",
                e.status,
                e.mode,
                e."startedAt",
                e."finishedAt",
                e.data,
                w.name as workflow_name,
                w.active as workflow_active
            FROM execution_entity e
            LEFT JOIN workflow_entity w ON e."workflowId" = w.id
            WHERE e."startedAt" >= $1
            ORDER BY e."startedAt" DESC
            LIMIT 1000
        """
        
        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(query, since)
                
                executions = []
                for row in rows:
                    execution = {
                        'id': row['id'],
                        'workflowId': row['workflowId'],
                        'workflow_name': row['workflow_name'],
                        'workflow_active': row['workflow_active'],
                        'status': row['status'],
                        'mode': row['mode'],
                        'startedAt': row['startedAt'],
                        'finishedAt': row['finishedAt'],
                        'data': row['data'] or {}
                    }
                    executions.append(execution)
                
                logger.info(f"Retrieved {len(executions)} recent executions", since=since)
                return executions
                
        except Exception as e:
            logger.error("Failed to get recent executions", error=str(e))
            raise

    async def get_workflow_metrics(self, date: datetime) -> List[Dict[str, Any]]:
        """Get workflow metrics for a specific date"""
        query = """
            SELECT 
                e."workflowId",
                w.name as workflow_name,
                COUNT(*) as total_executions,
                COUNT(CASE WHEN e.status = 'success' THEN 1 END) as successful_executions,
                COUNT(CASE WHEN e.status = 'error' THEN 1 END) as failed_executions,
                AVG(EXTRACT(EPOCH FROM (e."finishedAt" - e."startedAt")) * 1000) as avg_duration_ms,
                MAX(EXTRACT(EPOCH FROM (e."finishedAt" - e."startedAt")) * 1000) as max_duration_ms,
                MIN(EXTRACT(EPOCH FROM (e."finishedAt" - e."startedAt")) * 1000) as min_duration_ms,
                MAX(e."finishedAt") as last_execution
            FROM execution_entity e
            LEFT JOIN workflow_entity w ON e."workflowId" = w.id
            WHERE DATE(e."startedAt") = $1
            AND e."finishedAt" IS NOT NULL
            GROUP BY e."workflowId", w.name
        """
        
        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(query, date.date())
                
                metrics = []
                for row in rows:
                    metric = {
                        'workflow_id': row['workflowId'],
                        'workflow_name': row['workflow_name'] or 'Unknown',
                        'total_executions': row['total_executions'],
                        'successful_executions': row['successful_executions'],
                        'failed_executions': row['failed_executions'],
                        'avg_duration_ms': float(row['avg_duration_ms'] or 0),
                        'max_duration_ms': int(row['max_duration_ms'] or 0),
                        'min_duration_ms': int(row['min_duration_ms'] or 0),
                        'last_execution': row['last_execution'],
                        'date': date.date(),
                        'created_at': datetime.utcnow()
                    }
                    metrics.append(metric)
                
                logger.info(f"Retrieved workflow metrics for {date.date()}", workflows=len(metrics))
                return metrics
                
        except Exception as e:
            logger.error("Failed to get workflow metrics", error=str(e))
            raise

    async def get_node_performance(self, since: datetime) -> List[Dict[str, Any]]:
        """Get node performance data"""
        query = """
            SELECT 
                e.id as execution_id,
                e."workflowId",
                e.data
            FROM execution_entity e
            WHERE e."startedAt" >= $1
            AND e.data IS NOT NULL
            AND e.status = 'success'
            ORDER BY e."startedAt" DESC
            LIMIT 500
        """
        
        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(query, since)
                
                node_performance = []
                for row in rows:
                    execution_id = row['execution_id']
                    workflow_id = row['workflowId']
                    data = row['data'] or {}
                    
                    # Extract node performance from execution data
                    if 'resultData' in data and 'runData' in data['resultData']:
                        run_data = data['resultData']['runData']
                        
                        for node_name, node_data in run_data.items():
                            if isinstance(node_data, list) and node_data:
                                for run in node_data:
                                    if 'startTime' in run and 'executionTime' in run:
                                        performance = {
                                            'execution_id': execution_id,
                                            'workflow_id': workflow_id,
                                            'node_name': node_name,
                                            'node_type': run.get('source', [{}])[0].get('type', 'unknown') if run.get('source') else 'unknown',
                                            'duration_ms': run.get('executionTime', 0),
                                            'input_items': len(run.get('data', {}).get('main', [[]])[0]) if run.get('data') else 0,
                                            'output_items': len(run.get('data', {}).get('main', [[]])[0]) if run.get('data') else 0,
                                            'status': 'success' if not run.get('error') else 'error',
                                            'error_message': str(run.get('error', ''))[:500],
                                            'executed_at': datetime.fromtimestamp(run['startTime'] / 1000) if run.get('startTime') else datetime.utcnow(),
                                            'created_at': datetime.utcnow()
                                        }
                                        node_performance.append(performance)
                
                logger.info(f"Retrieved node performance data", nodes=len(node_performance))
                return node_performance
                
        except Exception as e:
            logger.error("Failed to get node performance", error=str(e))
            raise

    async def get_error_analysis(self, since: datetime) -> List[Dict[str, Any]]:
        """Get error analysis data"""
        query = """
            SELECT 
                e.id,
                e."workflowId",
                w.name as workflow_name,
                e."startedAt",
                e.data
            FROM execution_entity e
            LEFT JOIN workflow_entity w ON e."workflowId" = w.id
            WHERE e."startedAt" >= $1
            AND e.status = 'error'
            ORDER BY e."startedAt" DESC
            LIMIT 500
        """
        
        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(query, since)
                
                errors = []
                for row in rows:
                    execution_id = row['id']
                    workflow_id = row['workflowId']
                    workflow_name = row['workflow_name'] or 'Unknown'
                    occurred_at = row['startedAt']
                    data = row['data'] or {}
                    
                    # Extract error information
                    error_message = "Unknown error"
                    error_details = ""
                    node_name = "Unknown"
                    error_type = "execution_error"
                    
                    if 'resultData' in data and 'error' in data['resultData']:
                        error_info = data['resultData']['error']
                        error_message = str(error_info.get('message', 'Unknown error'))[:500]
                        error_details = str(error_info)[:1000]
                        node_name = error_info.get('node', {}).get('name', 'Unknown')
                        error_type = error_info.get('name', 'execution_error')
                    
                    error_analysis = {
                        'id': f"{execution_id}_{node_name}",
                        'execution_id': execution_id,
                        'workflow_id': workflow_id,
                        'workflow_name': workflow_name,
                        'node_name': node_name,
                        'error_type': error_type,
                        'error_message': error_message,
                        'error_details': error_details,
                        'occurred_at': occurred_at,
                        'resolved': False,
                        'created_at': datetime.utcnow()
                    }
                    errors.append(error_analysis)
                
                logger.info(f"Retrieved error analysis data", errors=len(errors))
                return errors
                
        except Exception as e:
            logger.error("Failed to get error analysis", error=str(e))
            raise

    async def get_workflows_info(self) -> List[Dict[str, Any]]:
        """Get workflow information"""
        query = """
            SELECT 
                id,
                name,
                active,
                "createdAt",
                "updatedAt",
                nodes,
                connections
            FROM workflow_entity
            ORDER BY "updatedAt" DESC
        """
        
        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch(query)
                
                workflows = []
                for row in rows:
                    workflow = {
                        'id': row['id'],
                        'name': row['name'],
                        'active': row['active'],
                        'created_at': row['createdAt'],
                        'updated_at': row['updatedAt'],
                        'node_count': len(row['nodes']) if row['nodes'] else 0,
                        'connection_count': len(row['connections']) if row['connections'] else 0
                    }
                    workflows.append(workflow)
                
                logger.info(f"Retrieved workflows info", workflows=len(workflows))
                return workflows
                
        except Exception as e:
            logger.error("Failed to get workflows info", error=str(e))
            raise

    async def close(self):
        """Close PostgreSQL connection pool"""
        if self.pool:
            try:
                await self.pool.close()
                self.pool = None
                self._initialized = False
                logger.info("PostgreSQL client closed")
            except Exception as e:
                logger.error("Error closing PostgreSQL client", error=str(e))
