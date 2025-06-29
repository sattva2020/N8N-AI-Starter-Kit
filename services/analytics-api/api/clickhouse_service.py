"""
ClickHouse Service для Analytics API
"""

import asyncio
from datetime import datetime, date, timedelta
from typing import List, Dict, Any, Optional
import structlog
from clickhouse_driver import Client as SyncClient
from clickhouse_driver.errors import Error as ClickHouseError

from .models import (
    WorkflowAnalytics, UserActivity, SystemMetrics, DocumentAnalytics,
    APIUsageStats, ErrorAnalysis, PerformanceReport, RealtimeDashboard,
    WorkflowMetrics, ErrorRecord
)

logger = structlog.get_logger(__name__)

class ClickHouseService:
    """ClickHouse service for analytics data"""
    
    def __init__(self, config):
        self.config = config
        self.client = None
        self._initialized = False

    async def initialize(self):
        """Initialize ClickHouse connection"""
        try:
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
            
            # Test connection directly with client to avoid circular dependency
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, lambda: self.client.execute("SELECT 1"))
            
            self._initialized = True
            logger.info("ClickHouse service initialized",
                       host=self.config.clickhouse_host,
                       database=self.config.clickhouse_database)
            
        except Exception as e:
            logger.error("Failed to initialize ClickHouse service", error=str(e))
            raise

    async def execute(self, query: str, params: Optional[Dict] = None) -> List[Any]:
        """Execute query asynchronously"""
        if not self._initialized:
            raise RuntimeError("ClickHouse service not initialized")
        
        try:
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

    async def get_workflow_analytics(self, start_date: date, end_date: date, workflow_id: Optional[str] = None) -> WorkflowAnalytics:
        """Get workflow analytics"""
        try:
            # Base conditions - используем toDate() для сравнения с started_at
            conditions = ["toDate(started_at) >= %(start_date)s", "toDate(started_at) <= %(end_date)s"]
            params = {"start_date": start_date, "end_date": end_date}
            
            if workflow_id:
                conditions.append("workflow_id = %(workflow_id)s")
                params["workflow_id"] = workflow_id
            
            where_clause = " AND ".join(conditions)
            
            # Total workflows count
            total_workflows_query = f"""
                SELECT count(DISTINCT workflow_id)
                FROM workflow_executions
                WHERE {where_clause}
            """
            total_workflows = (await self.execute(total_workflows_query, params))[0][0]
            
            # Active workflows (executed in period)
            active_workflows = total_workflows  # Same for the period
            
            # Execution statistics
            exec_stats_query = f"""
                SELECT 
                    count(*) as total_executions,
                    countIf(status = 'success') as successful_executions,
                    countIf(status = 'error') as failed_executions,
                    COALESCE(avg(duration_ms), 0) as avg_duration_ms
                FROM workflow_executions
                WHERE {where_clause}
            """
            exec_stats = (await self.execute(exec_stats_query, params))[0]
            
            # Executions by day
            executions_by_day_query = f"""
                SELECT 
                    toDate(started_at) as date,
                    count(*) as executions,
                    countIf(status = 'success') as successful,
                    countIf(status = 'error') as failed
                FROM workflow_executions
                WHERE {where_clause}
                GROUP BY toDate(started_at)
                ORDER BY toDate(started_at)
            """
            executions_by_day_data = await self.execute(executions_by_day_query, params)
            executions_by_day = [
                {
                    "date": str(row[0]),
                    "executions": row[1],
                    "successful": row[2],
                    "failed": row[3]
                }
                for row in executions_by_day_data
            ]
            
            # Top workflows
            top_workflows_query = f"""
                SELECT 
                    workflow_id,
                    workflow_name,
                    count(*) as total_executions,
                    countIf(status = 'success') as successful_executions,
                    countIf(status = 'error') as failed_executions,
                    COALESCE(avg(duration_ms), 0) as avg_duration_ms,
                    COALESCE(max(duration_ms), 0) as max_duration_ms,
                    COALESCE(min(duration_ms), 0) as min_duration_ms,
                    max(started_at) as last_execution
                FROM workflow_executions
                WHERE {where_clause}
                GROUP BY workflow_id, workflow_name
                ORDER BY total_executions DESC
                LIMIT 10
            """
            top_workflows_data = await self.execute(top_workflows_query, params)
            top_workflows = [
                WorkflowMetrics(
                    workflow_id=row[0],
                    workflow_name=row[1] or "Unknown",
                    total_executions=row[2],
                    successful_executions=row[3],
                    failed_executions=row[4],
                    success_rate=row[3] / row[2] if row[2] > 0 else 0,
                    avg_duration_ms=float(row[5] or 0),
                    max_duration_ms=int(row[6] or 0),
                    min_duration_ms=int(row[7] or 0),
                    last_execution=row[8]
                )
                for row in top_workflows_data
            ]
            
            # Failure rate trend
            failure_rate_trend_query = f"""
                SELECT 
                    toDate(started_at) as date,
                    CASE WHEN count(*) > 0 THEN countIf(status = 'error') * 100.0 / count(*) ELSE 0 END as failure_rate
                FROM workflow_executions
                WHERE {where_clause}
                GROUP BY toDate(started_at)
                ORDER BY toDate(started_at)
            """
            failure_rate_trend_data = await self.execute(failure_rate_trend_query, params)
            failure_rate_trend = [
                {"date": str(row[0]), "failure_rate": float(row[1])}
                for row in failure_rate_trend_data
            ]
            
            return WorkflowAnalytics(
                period={"start_date": start_date, "end_date": end_date},
                total_workflows=total_workflows,
                active_workflows=active_workflows,
                total_executions=exec_stats[0],
                successful_executions=exec_stats[1],
                failed_executions=exec_stats[2],
                avg_execution_time_ms=float(exec_stats[3] or 0),
                executions_by_day=executions_by_day,
                top_workflows=top_workflows,
                failure_rate_trend=failure_rate_trend
            )
            
        except Exception as e:
            logger.error("Failed to get workflow analytics", error=str(e))
            raise

    async def get_top_performing_workflows(self, start_date: date, end_date: date, limit: int = 10) -> List[Dict[str, Any]]:
        """Get top performing workflows"""
        try:
            query = """
                SELECT 
                    workflow_id,
                    workflow_name,
                    count(*) as total_executions,
                    countIf(status = 'success') as successful_executions,
                    CASE WHEN count(*) > 0 THEN countIf(status = 'success') * 100.0 / count(*) ELSE 0 END as success_rate,
                    COALESCE(avg(duration_ms), 0) as avg_duration_ms
                FROM workflow_executions
                WHERE toDate(started_at) >= %(start_date)s AND toDate(started_at) <= %(end_date)s
                GROUP BY workflow_id, workflow_name
                HAVING count(*) >= 5  -- At least 5 executions
                ORDER BY success_rate DESC, total_executions DESC
                LIMIT %(limit)s
            """
            
            result = await self.execute(query, {
                "start_date": start_date,
                "end_date": end_date,
                "limit": limit
            })
            
            return [
                {
                    "workflow_id": row[0],
                    "workflow_name": row[1] or "Unknown",
                    "total_executions": row[2],
                    "successful_executions": row[3],
                    "success_rate": float(row[4]),
                    "avg_duration_ms": float(row[5] or 0)
                }
                for row in result
            ]
            
        except Exception as e:
            logger.error("Failed to get top performing workflows", error=str(e))
            raise

    async def get_user_activity(self, start_date: date, end_date: date, user_id: Optional[str] = None, offset: int = 0, limit: int = 100) -> UserActivity:
        """Get user activity analytics"""
        try:
            # This is a placeholder - actual implementation depends on having user_activity table
            # For now, return mock data structure
            return UserActivity(
                period={"start_date": start_date, "end_date": end_date},
                total_users=0,
                active_users=0,
                new_users=0,
                activity_by_day=[],
                top_actions=[],
                user_engagement={},
                activities=[]
            )
            
        except Exception as e:
            logger.error("Failed to get user activity", error=str(e))
            raise

    async def get_system_metrics(self, start_time: datetime, end_time: datetime, metric_type: Optional[str] = None) -> SystemMetrics:
        """Get system metrics"""
        try:
            # Placeholder implementation
            return SystemMetrics(
                period={"start_time": start_time, "end_time": end_time},
                cpu_usage=[],
                memory_usage=[],
                disk_usage=[],
                network_traffic=[],
                response_times=[],
                error_rates=[],
                metrics=[]
            )
            
        except Exception as e:
            logger.error("Failed to get system metrics", error=str(e))
            raise

    async def get_document_analytics(self, start_date: date, end_date: date, document_type: Optional[str] = None) -> DocumentAnalytics:
        """Get document analytics"""
        try:
            # Placeholder implementation
            return DocumentAnalytics(
                period={"start_date": start_date, "end_date": end_date},
                total_documents=0,
                processed_documents=0,
                failed_documents=0,
                processing_success_rate=0.0,
                avg_processing_time_ms=0.0,
                documents_by_type=[],
                processing_by_day=[],
                top_document_types=[]
            )
            
        except Exception as e:
            logger.error("Failed to get document analytics", error=str(e))
            raise

    async def get_api_usage_stats(self, start_date: date, end_date: date, endpoint: Optional[str] = None) -> APIUsageStats:
        """Get API usage statistics"""
        try:
            # Placeholder implementation
            return APIUsageStats(
                period={"start_date": start_date, "end_date": end_date},
                total_requests=0,
                successful_requests=0,
                failed_requests=0,
                avg_response_time_ms=0.0,
                requests_by_endpoint=[],
                requests_by_day=[],
                top_endpoints=[],
                error_distribution=[]
            )
            
        except Exception as e:
            logger.error("Failed to get API usage stats", error=str(e))
            raise

    async def get_error_analysis(self, start_date: date, end_date: date, error_type: Optional[str] = None, workflow_id: Optional[str] = None) -> ErrorAnalysis:
        """Get error analysis"""
        try:
            conditions = ["toDate(created_at) >= %(start_date)s", "toDate(created_at) <= %(end_date)s"]
            params = {"start_date": start_date, "end_date": end_date}
            
            if error_type:
                conditions.append("error_type = %(error_type)s")
                params["error_type"] = error_type
                
            if workflow_id:
                conditions.append("workflow_id = %(workflow_id)s")
                params["workflow_id"] = workflow_id
            
            where_clause = " AND ".join(conditions)
            
            # Error statistics
            error_stats_query = f"""
                SELECT 
                    count(*) as total_errors,
                    countIf(resolved = 1) as resolved_errors,
                    countIf(resolved = 0) as unresolved_errors
                FROM error_analysis
                WHERE {where_clause}
            """
            error_stats = (await self.execute(error_stats_query, params))[0]
            
            # Errors by type
            errors_by_type_query = f"""
                SELECT 
                    error_type,
                    count(*) as error_count
                FROM error_analysis
                WHERE {where_clause}
                GROUP BY error_type
                ORDER BY error_count DESC
                LIMIT 10
            """
            errors_by_type_data = await self.execute(errors_by_type_query, params)
            errors_by_type = [
                {"error_type": row[0], "count": row[1]}
                for row in errors_by_type_data
            ]
            
            # Other analysis...
            return ErrorAnalysis(
                period={"start_date": start_date, "end_date": end_date},
                total_errors=error_stats[0],
                resolved_errors=error_stats[1],
                unresolved_errors=error_stats[2],
                errors_by_type=errors_by_type,
                errors_by_workflow=[],
                errors_by_day=[],
                top_error_messages=[],
                error_trends=[],
                errors=[]
            )
            
        except Exception as e:
            logger.error("Failed to get error analysis", error=str(e))
            raise

    async def get_performance_report(self, start_date: date, end_date: date, report_type: str) -> PerformanceReport:
        """Get performance report"""
        try:
            # Placeholder implementation
            return PerformanceReport(
                period={"start_date": start_date, "end_date": end_date},
                report_type=report_type,
                generated_at=datetime.utcnow(),
                kpis=[],
                workflow_performance={},
                system_performance={},
                user_performance={},
                trends=[],
                insights=[],
                recommendations=[]
            )
            
        except Exception as e:
            logger.error("Failed to get performance report", error=str(e))
            raise

    async def get_realtime_dashboard_data(self, start_time: datetime, end_time: datetime) -> RealtimeDashboard:
        """Get real-time dashboard data"""
        try:
            # Active workflows (executed in last hour)
            active_workflows_query = """
                SELECT count(DISTINCT workflow_id)
                FROM workflow_executions
                WHERE started_at >= %(start_time)s AND started_at <= %(end_time)s
            """
            active_workflows = (await self.execute(active_workflows_query, {
                "start_time": start_time, "end_time": end_time
            }))[0][0]
            
            # Current executions (last 5 minutes)
            current_start = end_time - timedelta(minutes=5)
            current_executions_query = """
                SELECT count(*)
                FROM workflow_executions
                WHERE started_at >= %(start_time)s AND started_at <= %(end_time)s
            """
            current_executions = (await self.execute(current_executions_query, {
                "start_time": current_start, "end_time": end_time
            }))[0][0]
            
            # Success rate last hour
            success_rate_query = """
                SELECT 
                    countIf(status = 'success') * 100.0 / count(*) as success_rate
                FROM workflow_executions
                WHERE started_at >= %(start_time)s AND started_at <= %(end_time)s
            """
            success_rate_result = await self.execute(success_rate_query, {
                "start_time": start_time, "end_time": end_time
            })
            success_rate = float(success_rate_result[0][0] or 0)
            
            return RealtimeDashboard(
                timestamp=datetime.utcnow(),
                active_workflows=active_workflows,
                current_executions=current_executions,
                success_rate_last_hour=success_rate,
                avg_response_time_ms=0.0,  # Placeholder
                active_users=0,  # Placeholder
                system_health={},  # Placeholder
                recent_errors=[],  # Placeholder
                resource_usage={}  # Placeholder
            )
            
        except Exception as e:
            logger.error("Failed to get realtime dashboard data", error=str(e))
            raise

    async def health_check(self) -> bool:
        """Health check for ClickHouse"""
        try:
            await self.execute("SELECT 1")
            return True
        except Exception:
            return False

    async def close(self):
        """Close ClickHouse connection"""
        if self.client:
            try:
                self.client = None
                self._initialized = False
                logger.info("ClickHouse service closed")
            except Exception as e:
                logger.error("Error closing ClickHouse service", error=str(e))
