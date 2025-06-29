"""
N8N Analytics API
REST API для доступа к аналитическим данным из ClickHouse
"""

import asyncio
import logging
import os
import signal
import sys
from datetime import datetime, timedelta, date
from typing import Dict, List, Optional, Any
from contextlib import asynccontextmanager

import structlog
import uvicorn
from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from pydantic import BaseModel, Field

from api.clickhouse_service import ClickHouseService
from api.cache_service import CacheService
from api.config import APIConfig
from api.models import (
    WorkflowAnalytics,
    UserActivity,
    SystemMetrics,
    DocumentAnalytics,
    APIUsageStats,
    ErrorAnalysis,
    PerformanceReport
)

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
API_REQUESTS = Counter('analytics_api_requests_total', 'Total API requests', ['endpoint', 'method', 'status'])
REQUEST_DURATION = Histogram('analytics_api_request_duration_seconds', 'Request duration', ['endpoint'])
CACHE_HITS = Counter('analytics_api_cache_hits_total', 'Cache hits', ['type'])
CACHE_MISSES = Counter('analytics_api_cache_misses_total', 'Cache misses', ['type'])

class DateRange(BaseModel):
    """Модель для диапазона дат"""
    start_date: date
    end_date: date

class TimeRange(BaseModel):
    """Модель для временного диапазона"""
    start_time: datetime
    end_time: datetime

class PaginationParams(BaseModel):
    """Параметры пагинации"""
    offset: int = Field(default=0, ge=0)
    limit: int = Field(default=100, ge=1, le=1000)

# Global services
config = APIConfig()
clickhouse_service = ClickHouseService(config)
cache_service = CacheService(config)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager for the application"""
    # Startup
    logger.info("Starting Analytics API")
    await clickhouse_service.initialize()
    await cache_service.initialize()
    
    yield
    
    # Shutdown
    logger.info("Shutting down Analytics API")
    await clickhouse_service.close()
    await cache_service.close()

# FastAPI app
app = FastAPI(
    title="N8N Analytics API",
    description="API для доступа к аналитическим данным N8N AI Starter Kit",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency для проверки API ключей (если нужно)
async def verify_api_key(api_key: Optional[str] = Query(None)):
    """Проверка API ключа"""
    if config.require_api_key and not api_key:
        raise HTTPException(status_code=401, detail="API key required")
    return api_key

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Проверяем подключение к ClickHouse
        await clickhouse_service.health_check()
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow(),
            "services": {
                "clickhouse": "healthy",
                "cache": "healthy" if cache_service.is_connected() else "unhealthy"
            }
        }
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")

@app.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

# Workflow Analytics Endpoints

@app.get("/api/v1/workflows/analytics", response_model=WorkflowAnalytics)
async def get_workflow_analytics(
    start_date: date = Query(..., description="Дата начала"),
    end_date: date = Query(..., description="Дата окончания"),
    workflow_id: Optional[str] = Query(None, description="ID воркфлоу"),
    api_key: str = Depends(verify_api_key)
):
    """Получить аналитику по воркфлоу"""
    with REQUEST_DURATION.labels(endpoint='workflows_analytics').time():
        try:
            # Проверяем кэш
            cache_key = f"workflow_analytics:{start_date}:{end_date}:{workflow_id or 'all'}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='workflow_analytics').inc()
                API_REQUESTS.labels(endpoint='workflows_analytics', method='GET', status='200').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='workflow_analytics').inc()
            
            # Получаем данные из ClickHouse
            analytics = await clickhouse_service.get_workflow_analytics(
                start_date, end_date, workflow_id
            )
            
            # Кэшируем результат на 15 минут
            await cache_service.set(cache_key, analytics.dict(), ttl=900)
            
            API_REQUESTS.labels(endpoint='workflows_analytics', method='GET', status='200').inc()
            return analytics
            
        except Exception as e:
            logger.error("Failed to get workflow analytics", error=str(e))
            API_REQUESTS.labels(endpoint='workflows_analytics', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/workflows/top-performers")
async def get_top_performing_workflows(
    start_date: date = Query(...),
    end_date: date = Query(...),
    limit: int = Query(10, ge=1, le=50),
    api_key: str = Depends(verify_api_key)
):
    """Получить топ самых производительных воркфлоу"""
    with REQUEST_DURATION.labels(endpoint='top_workflows').time():
        try:
            cache_key = f"top_workflows:{start_date}:{end_date}:{limit}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='top_workflows').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='top_workflows').inc()
            
            top_workflows = await clickhouse_service.get_top_performing_workflows(
                start_date, end_date, limit
            )
            
            await cache_service.set(cache_key, top_workflows, ttl=1800)  # 30 минут
            API_REQUESTS.labels(endpoint='top_workflows', method='GET', status='200').inc()
            
            return top_workflows
            
        except Exception as e:
            logger.error("Failed to get top workflows", error=str(e))
            API_REQUESTS.labels(endpoint='top_workflows', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# User Activity Endpoints

@app.get("/api/v1/users/activity", response_model=UserActivity)
async def get_user_activity(
    start_date: date = Query(...),
    end_date: date = Query(...),
    user_id: Optional[str] = Query(None),
    pagination: PaginationParams = Depends(),
    api_key: str = Depends(verify_api_key)
):
    """Получить активность пользователей"""
    with REQUEST_DURATION.labels(endpoint='user_activity').time():
        try:
            cache_key = f"user_activity:{start_date}:{end_date}:{user_id or 'all'}:{pagination.offset}:{pagination.limit}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='user_activity').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='user_activity').inc()
            
            activity = await clickhouse_service.get_user_activity(
                start_date, end_date, user_id, pagination.offset, pagination.limit
            )
            
            await cache_service.set(cache_key, activity.dict(), ttl=600)  # 10 минут
            API_REQUESTS.labels(endpoint='user_activity', method='GET', status='200').inc()
            
            return activity
            
        except Exception as e:
            logger.error("Failed to get user activity", error=str(e))
            API_REQUESTS.labels(endpoint='user_activity', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# System Metrics Endpoints

@app.get("/api/v1/system/metrics", response_model=SystemMetrics)
async def get_system_metrics(
    start_time: datetime = Query(...),
    end_time: datetime = Query(...),
    metric_type: Optional[str] = Query(None, description="Тип метрики"),
    api_key: str = Depends(verify_api_key)
):
    """Получить системные метрики"""
    with REQUEST_DURATION.labels(endpoint='system_metrics').time():
        try:
            cache_key = f"system_metrics:{start_time}:{end_time}:{metric_type or 'all'}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='system_metrics').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='system_metrics').inc()
            
            metrics = await clickhouse_service.get_system_metrics(
                start_time, end_time, metric_type
            )
            
            await cache_service.set(cache_key, metrics.dict(), ttl=300)  # 5 минут
            API_REQUESTS.labels(endpoint='system_metrics', method='GET', status='200').inc()
            
            return metrics
            
        except Exception as e:
            logger.error("Failed to get system metrics", error=str(e))
            API_REQUESTS.labels(endpoint='system_metrics', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# Document Analytics Endpoints

@app.get("/api/v1/documents/analytics", response_model=DocumentAnalytics)
async def get_document_analytics(
    start_date: date = Query(...),
    end_date: date = Query(...),
    document_type: Optional[str] = Query(None),
    api_key: str = Depends(verify_api_key)
):
    """Получить аналитику по документам"""
    with REQUEST_DURATION.labels(endpoint='document_analytics').time():
        try:
            cache_key = f"document_analytics:{start_date}:{end_date}:{document_type or 'all'}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='document_analytics').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='document_analytics').inc()
            
            analytics = await clickhouse_service.get_document_analytics(
                start_date, end_date, document_type
            )
            
            await cache_service.set(cache_key, analytics.dict(), ttl=900)  # 15 минут
            API_REQUESTS.labels(endpoint='document_analytics', method='GET', status='200').inc()
            
            return analytics
            
        except Exception as e:
            logger.error("Failed to get document analytics", error=str(e))
            API_REQUESTS.labels(endpoint='document_analytics', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# API Usage Statistics

@app.get("/api/v1/api/usage", response_model=APIUsageStats)
async def get_api_usage_stats(
    start_date: date = Query(...),
    end_date: date = Query(...),
    endpoint: Optional[str] = Query(None),
    api_key: str = Depends(verify_api_key)
):
    """Получить статистику использования API"""
    with REQUEST_DURATION.labels(endpoint='api_usage').time():
        try:
            cache_key = f"api_usage:{start_date}:{end_date}:{endpoint or 'all'}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='api_usage').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='api_usage').inc()
            
            usage_stats = await clickhouse_service.get_api_usage_stats(
                start_date, end_date, endpoint
            )
            
            await cache_service.set(cache_key, usage_stats.dict(), ttl=1200)  # 20 минут
            API_REQUESTS.labels(endpoint='api_usage', method='GET', status='200').inc()
            
            return usage_stats
            
        except Exception as e:
            logger.error("Failed to get API usage stats", error=str(e))
            API_REQUESTS.labels(endpoint='api_usage', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# Error Analysis

@app.get("/api/v1/errors/analysis", response_model=ErrorAnalysis)
async def get_error_analysis(
    start_date: date = Query(...),
    end_date: date = Query(...),
    error_type: Optional[str] = Query(None),
    workflow_id: Optional[str] = Query(None),
    api_key: str = Depends(verify_api_key)
):
    """Получить анализ ошибок"""
    with REQUEST_DURATION.labels(endpoint='error_analysis').time():
        try:
            cache_key = f"error_analysis:{start_date}:{end_date}:{error_type or 'all'}:{workflow_id or 'all'}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='error_analysis').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='error_analysis').inc()
            
            error_analysis = await clickhouse_service.get_error_analysis(
                start_date, end_date, error_type, workflow_id
            )
            
            await cache_service.set(cache_key, error_analysis.dict(), ttl=600)  # 10 минут
            API_REQUESTS.labels(endpoint='error_analysis', method='GET', status='200').inc()
            
            return error_analysis
            
        except Exception as e:
            logger.error("Failed to get error analysis", error=str(e))
            API_REQUESTS.labels(endpoint='error_analysis', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# Performance Reports

@app.get("/api/v1/performance/report", response_model=PerformanceReport)
async def get_performance_report(
    start_date: date = Query(...),
    end_date: date = Query(...),
    report_type: str = Query("summary", description="Тип отчета: summary, detailed, trends"),
    api_key: str = Depends(verify_api_key)
):
    """Получить отчет о производительности"""
    with REQUEST_DURATION.labels(endpoint='performance_report').time():
        try:
            cache_key = f"performance_report:{start_date}:{end_date}:{report_type}"
            cached_result = await cache_service.get(cache_key)
            
            if cached_result:
                CACHE_HITS.labels(type='performance_report').inc()
                return JSONResponse(content=cached_result)
            
            CACHE_MISSES.labels(type='performance_report').inc()
            
            report = await clickhouse_service.get_performance_report(
                start_date, end_date, report_type
            )
            
            await cache_service.set(cache_key, report.dict(), ttl=1800)  # 30 минут
            API_REQUESTS.labels(endpoint='performance_report', method='GET', status='200').inc()
            
            return report
            
        except Exception as e:
            logger.error("Failed to get performance report", error=str(e))
            API_REQUESTS.labels(endpoint='performance_report', method='GET', status='500').inc()
            raise HTTPException(status_code=500, detail=str(e))

# Real-time endpoints

@app.get("/api/v1/realtime/dashboard")
async def get_realtime_dashboard(api_key: str = Depends(verify_api_key)):
    """Получить данные для real-time дашборда"""
    try:
        # Получаем данные за последний час
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=1)
        
        dashboard_data = await clickhouse_service.get_realtime_dashboard_data(
            start_time, end_time
        )
        
        API_REQUESTS.labels(endpoint='realtime_dashboard', method='GET', status='200').inc()
        return dashboard_data
        
    except Exception as e:
        logger.error("Failed to get realtime dashboard", error=str(e))
        API_REQUESTS.labels(endpoint='realtime_dashboard', method='GET', status='500').inc()
        raise HTTPException(status_code=500, detail=str(e))

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
