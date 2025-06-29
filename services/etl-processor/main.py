"""
N8N Analytics ETL Processor
Обрабатывает данные из N8N PostgreSQL и загружает в ClickHouse для аналитики
"""

import asyncio
import logging
import os
import signal
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from contextlib import asynccontextmanager

import schedule
import structlog
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from pydantic import BaseModel

from etl.clickhouse_client import ClickHouseClient
from etl.postgres_client import PostgresClient
from etl.n8n_api_client import N8NAPIClient
from etl.processors import (
    WorkflowExecutionProcessor,
    WorkflowMetricsProcessor,
    NodePerformanceProcessor,
    ErrorAnalysisProcessor
)
from etl.config import ETLConfig

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)

# Prometheus metrics
JOBS_COUNTER = Counter('etl_jobs_total', 'Total number of ETL jobs processed', ['job_type', 'status'])
JOB_DURATION = Histogram('etl_job_duration_seconds', 'Time spent processing ETL jobs', ['job_type'])
RECORDS_PROCESSED = Counter('etl_records_processed_total', 'Total number of records processed', ['table'])

class ETLStatus(BaseModel):
    """ETL status response model"""
    status: str
    last_run: Optional[datetime]
    next_run: Optional[datetime]
    processed_records: Dict[str, int]
    errors: List[str]

class ETLProcessor:
    """Main ETL processor class"""
    
    def __init__(self):
        self.config = ETLConfig()
        self.clickhouse_client = ClickHouseClient(self.config)
        self.postgres_client = PostgresClient(self.config)
        self.n8n_api_client = N8NAPIClient(self.config)
        
        # Processors
        self.workflow_execution_processor = WorkflowExecutionProcessor(
            self.postgres_client, self.clickhouse_client
        )
        self.workflow_metrics_processor = WorkflowMetricsProcessor(
            self.postgres_client, self.clickhouse_client
        )
        self.node_performance_processor = NodePerformanceProcessor(
            self.postgres_client, self.clickhouse_client
        )
        self.error_analysis_processor = ErrorAnalysisProcessor(
            self.postgres_client, self.clickhouse_client
        )
        
        self.last_run = None
        self.next_run = None
        self.processed_records = {}
        self.errors = []
        self.is_running = False

    async def initialize(self):
        """Initialize ETL processor"""
        try:
            logger.info("Initializing ETL processor")
            
            # Initialize clients
            await self.clickhouse_client.initialize()
            await self.postgres_client.initialize()
            await self.n8n_api_client.initialize()
            
            # Create ClickHouse tables
            await self.create_clickhouse_tables()
            
            # Schedule jobs
            self.schedule_jobs()
            
            logger.info("ETL processor initialized successfully")
            
        except Exception as e:
            logger.error("Failed to initialize ETL processor", error=str(e))
            raise

    async def create_clickhouse_tables(self):
        """Create ClickHouse tables for analytics"""
        tables = {
            'workflow_executions': '''
                CREATE TABLE IF NOT EXISTS workflow_executions (
                    id String,
                    workflow_id String,
                    workflow_name String,
                    status String,
                    mode String,
                    started_at DateTime64(3),
                    finished_at DateTime64(3),
                    duration_ms UInt32,
                    data_processed UInt32,
                    created_at DateTime64(3) DEFAULT now(),
                    INDEX idx_workflow_id workflow_id TYPE bloom_filter GRANULARITY 1,
                    INDEX idx_status status TYPE set(0) GRANULARITY 1,
                    INDEX idx_started_at started_at TYPE minmax GRANULARITY 1
                ) ENGINE = MergeTree()
                PARTITION BY toYYYYMM(started_at)
                ORDER BY (workflow_id, started_at)
                TTL toDateTime(started_at) + INTERVAL 1 YEAR
            ''',
            
            'workflow_metrics': '''
                CREATE TABLE IF NOT EXISTS workflow_metrics (
                    workflow_id String,
                    workflow_name String,
                    total_executions UInt32,
                    successful_executions UInt32,
                    failed_executions UInt32,
                    avg_duration_ms Float32,
                    max_duration_ms UInt32,
                    min_duration_ms UInt32,
                    last_execution DateTime64(3),
                    date Date,
                    created_at DateTime64(3) DEFAULT now()
                ) ENGINE = ReplacingMergeTree(created_at)
                PARTITION BY toYYYYMM(date)
                ORDER BY (workflow_id, date)
                TTL date + INTERVAL 2 YEAR
            ''',
            
            'node_performance': '''
                CREATE TABLE IF NOT EXISTS node_performance (
                    execution_id String,
                    workflow_id String,
                    node_name String,
                    node_type String,
                    duration_ms UInt32,
                    input_items UInt32,
                    output_items UInt32,
                    status String,
                    error_message String,
                    executed_at DateTime64(3),
                    created_at DateTime64(3) DEFAULT now(),
                    INDEX idx_workflow_id workflow_id TYPE bloom_filter GRANULARITY 1,
                    INDEX idx_node_type node_type TYPE set(0) GRANULARITY 1
                ) ENGINE = MergeTree()
                PARTITION BY toYYYYMM(executed_at)
                ORDER BY (workflow_id, executed_at, node_name)
                TTL toDateTime(executed_at) + INTERVAL 6 MONTH
            ''',
            
            'error_analysis': '''
                CREATE TABLE IF NOT EXISTS error_analysis (
                    id String,
                    execution_id String,
                    workflow_id String,
                    workflow_name String,
                    node_name String,
                    error_type String,
                    error_message String,
                    error_details String,
                    occurred_at DateTime64(3),
                    resolved Bool DEFAULT false,
                    created_at DateTime64(3) DEFAULT now(),
                    INDEX idx_error_type error_type TYPE set(0) GRANULARITY 1,
                    INDEX idx_workflow_id workflow_id TYPE bloom_filter GRANULARITY 1
                ) ENGINE = MergeTree()
                PARTITION BY toYYYYMM(occurred_at)
                ORDER BY (error_type, occurred_at)
                TTL toDateTime(occurred_at) + INTERVAL 1 YEAR
            '''
        }
        
        for table_name, ddl in tables.items():
            try:
                await self.clickhouse_client.execute(ddl)
                logger.info(f"Created/verified table: {table_name}")
            except Exception as e:
                logger.error(f"Failed to create table {table_name}", error=str(e))
                raise

    def schedule_jobs(self):
        """Schedule ETL jobs"""
        # Every 5 minutes - recent executions
        schedule.every(5).minutes.do(self.run_recent_executions_job)
        
        # Every 30 minutes - workflow metrics
        schedule.every(30).minutes.do(self.run_workflow_metrics_job)
        
        # Every hour - node performance analysis
        schedule.every().hour.do(self.run_node_performance_job)
        
        # Every 6 hours - error analysis
        schedule.every(6).hours.do(self.run_error_analysis_job)
        
        # Daily - full sync
        schedule.every().day.at("02:00").do(self.run_full_sync_job)

    async def run_recent_executions_job(self):
        """Process recent workflow executions"""
        if self.is_running:
            logger.warning("ETL job already running, skipping")
            return
            
        self.is_running = True
        job_type = "recent_executions"
        
        try:
            with JOB_DURATION.labels(job_type=job_type).time():
                logger.info("Starting recent executions job")
                
                # Process executions from last 10 minutes
                since = datetime.utcnow() - timedelta(minutes=10)
                records = await self.workflow_execution_processor.process_recent_executions(since)
                
                RECORDS_PROCESSED.labels(table='workflow_executions').inc(records)
                JOBS_COUNTER.labels(job_type=job_type, status='success').inc()
                
                self.processed_records['workflow_executions'] = records
                self.last_run = datetime.utcnow()
                
                logger.info(f"Recent executions job completed", records_processed=records)
                
        except Exception as e:
            JOBS_COUNTER.labels(job_type=job_type, status='error').inc()
            error_msg = f"Recent executions job failed: {str(e)}"
            self.errors.append(error_msg)
            logger.error(error_msg, error=str(e))
        finally:
            self.is_running = False

    async def run_workflow_metrics_job(self):
        """Process workflow metrics"""
        if self.is_running:
            return
            
        self.is_running = True
        job_type = "workflow_metrics"
        
        try:
            with JOB_DURATION.labels(job_type=job_type).time():
                logger.info("Starting workflow metrics job")
                
                records = await self.workflow_metrics_processor.process_daily_metrics()
                
                RECORDS_PROCESSED.labels(table='workflow_metrics').inc(records)
                JOBS_COUNTER.labels(job_type=job_type, status='success').inc()
                
                self.processed_records['workflow_metrics'] = records
                
                logger.info(f"Workflow metrics job completed", records_processed=records)
                
        except Exception as e:
            JOBS_COUNTER.labels(job_type=job_type, status='error').inc()
            error_msg = f"Workflow metrics job failed: {str(e)}"
            self.errors.append(error_msg)
            logger.error(error_msg, error=str(e))
        finally:
            self.is_running = False

    async def run_node_performance_job(self):
        """Process node performance data"""
        if self.is_running:
            return
            
        self.is_running = True
        job_type = "node_performance"
        
        try:
            with JOB_DURATION.labels(job_type=job_type).time():
                logger.info("Starting node performance job")
                
                since = datetime.utcnow() - timedelta(hours=2)
                records = await self.node_performance_processor.process_node_performance(since)
                
                RECORDS_PROCESSED.labels(table='node_performance').inc(records)
                JOBS_COUNTER.labels(job_type=job_type, status='success').inc()
                
                self.processed_records['node_performance'] = records
                
                logger.info(f"Node performance job completed", records_processed=records)
                
        except Exception as e:
            JOBS_COUNTER.labels(job_type=job_type, status='error').inc()
            error_msg = f"Node performance job failed: {str(e)}"
            self.errors.append(error_msg)
            logger.error(error_msg, error=str(e))
        finally:
            self.is_running = False

    async def run_error_analysis_job(self):
        """Process error analysis"""
        if self.is_running:
            return
            
        self.is_running = True
        job_type = "error_analysis"
        
        try:
            with JOB_DURATION.labels(job_type=job_type).time():
                logger.info("Starting error analysis job")
                
                since = datetime.utcnow() - timedelta(hours=8)
                records = await self.error_analysis_processor.process_errors(since)
                
                RECORDS_PROCESSED.labels(table='error_analysis').inc(records)
                JOBS_COUNTER.labels(job_type=job_type, status='success').inc()
                
                self.processed_records['error_analysis'] = records
                
                logger.info(f"Error analysis job completed", records_processed=records)
                
        except Exception as e:
            JOBS_COUNTER.labels(job_type=job_type, status='error').inc()
            error_msg = f"Error analysis job failed: {str(e)}"
            self.errors.append(error_msg)
            logger.error(error_msg, error=str(e))
        finally:
            self.is_running = False

    async def run_full_sync_job(self):
        """Run full data synchronization"""
        if self.is_running:
            return
            
        self.is_running = True
        job_type = "full_sync"
        
        try:
            with JOB_DURATION.labels(job_type=job_type).time():
                logger.info("Starting full sync job")
                
                # Run all processors for the last 24 hours
                since = datetime.utcnow() - timedelta(days=1)
                
                total_records = 0
                total_records += await self.workflow_execution_processor.process_recent_executions(since)
                total_records += await self.workflow_metrics_processor.process_daily_metrics()
                total_records += await self.node_performance_processor.process_node_performance(since)
                total_records += await self.error_analysis_processor.process_errors(since)
                
                JOBS_COUNTER.labels(job_type=job_type, status='success').inc()
                
                logger.info(f"Full sync job completed", total_records=total_records)
                
        except Exception as e:
            JOBS_COUNTER.labels(job_type=job_type, status='error').inc()
            error_msg = f"Full sync job failed: {str(e)}"
            self.errors.append(error_msg)
            logger.error(error_msg, error=str(e))
        finally:
            self.is_running = False

    def get_status(self) -> ETLStatus:
        """Get ETL processor status"""
        # Calculate next run time
        next_run = None
        if schedule.jobs:
            next_job = min(schedule.jobs, key=lambda job: job.next_run)
            next_run = next_job.next_run
        
        return ETLStatus(
            status="running" if self.is_running else "idle",
            last_run=self.last_run,
            next_run=next_run,
            processed_records=self.processed_records,
            errors=self.errors[-10:]  # Last 10 errors
        )

    async def cleanup(self):
        """Cleanup resources"""
        logger.info("Shutting down ETL processor")
        await self.clickhouse_client.close()
        await self.postgres_client.close()
        await self.n8n_api_client.close()

async def run_scheduler():
    """Run scheduled jobs"""
    while True:
        schedule.run_pending()
        await asyncio.sleep(30)

# Global variables for background tasks
scheduler_task = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    global scheduler_task
    # Startup
    await etl_processor.initialize()
    scheduler_task = asyncio.create_task(run_scheduler())
    yield
    # Shutdown
    if scheduler_task:
        scheduler_task.cancel()
        try:
            await scheduler_task
        except asyncio.CancelledError:
            pass
    await etl_processor.cleanup()

# Global ETL processor instance
etl_processor = ETLProcessor()

# FastAPI app
app = FastAPI(
    title="N8N Analytics ETL Processor",
    description="ETL processor for N8N workflow analytics",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.utcnow()}

@app.get("/status", response_model=ETLStatus)
async def get_status():
    """Get ETL processor status"""
    return etl_processor.get_status()

@app.post("/trigger/{job_type}")
async def trigger_job(job_type: str):
    """Manually trigger ETL job"""
    if etl_processor.is_running:
        raise HTTPException(status_code=409, detail="ETL job already running")
    
    job_methods = {
        "recent_executions": etl_processor.run_recent_executions_job,
        "workflow_metrics": etl_processor.run_workflow_metrics_job,
        "node_performance": etl_processor.run_node_performance_job,
        "error_analysis": etl_processor.run_error_analysis_job,
        "full_sync": etl_processor.run_full_sync_job
    }
    
    if job_type not in job_methods:
        raise HTTPException(status_code=400, detail=f"Unknown job type: {job_type}")
    
    # Run job in background
    asyncio.create_task(job_methods[job_type]())
    
    return {"message": f"Job {job_type} triggered", "timestamp": datetime.utcnow()}

@app.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Run the FastAPI app
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_config=None  # Use structlog
    )
