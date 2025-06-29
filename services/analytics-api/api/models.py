"""
Pydantic models for Analytics API
"""

from datetime import datetime, date
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field

class WorkflowExecution(BaseModel):
    """Модель выполнения воркфлоу"""
    id: str
    workflow_id: str
    workflow_name: str
    status: str
    mode: str
    started_at: datetime
    finished_at: Optional[datetime]
    duration_ms: int
    data_processed: int

class WorkflowMetrics(BaseModel):
    """Метрики воркфлоу"""
    workflow_id: str
    workflow_name: str
    total_executions: int
    successful_executions: int
    failed_executions: int
    success_rate: float
    avg_duration_ms: float
    max_duration_ms: int
    min_duration_ms: int
    last_execution: Optional[datetime]

class WorkflowAnalytics(BaseModel):
    """Аналитика по воркфлоу"""
    period: Dict[str, date] = Field(description="Период анализа")
    total_workflows: int = Field(description="Общее количество воркфлоу")
    active_workflows: int = Field(description="Активные воркфлоу")
    total_executions: int = Field(description="Общее количество выполнений")
    successful_executions: int = Field(description="Успешные выполнения")
    failed_executions: int = Field(description="Неудачные выполнения")
    avg_execution_time_ms: float = Field(description="Среднее время выполнения")
    executions_by_day: List[Dict[str, Any]] = Field(description="Выполнения по дням")
    top_workflows: List[WorkflowMetrics] = Field(description="Топ воркфлоу")
    failure_rate_trend: List[Dict[str, Any]] = Field(description="Тренд ошибок")

class UserActivityRecord(BaseModel):
    """Запись активности пользователя"""
    user_id: str
    action: str
    resource_type: str
    resource_id: str
    timestamp: datetime
    metadata: Dict[str, Any]

class UserActivity(BaseModel):
    """Активность пользователей"""
    period: Dict[str, date]
    total_users: int = Field(description="Общее количество пользователей")
    active_users: int = Field(description="Активные пользователи")
    new_users: int = Field(description="Новые пользователи")
    activity_by_day: List[Dict[str, Any]] = Field(description="Активность по дням")
    top_actions: List[Dict[str, Any]] = Field(description="Топ действий")
    user_engagement: Dict[str, Any] = Field(description="Вовлеченность пользователей")
    activities: List[UserActivityRecord] = Field(description="Записи активности")

class SystemMetric(BaseModel):
    """Системная метрика"""
    timestamp: datetime
    metric_name: str
    metric_value: float
    metric_unit: str
    labels: Dict[str, str]

class SystemMetrics(BaseModel):
    """Системные метрики"""
    period: Dict[str, datetime]
    cpu_usage: List[Dict[str, Any]] = Field(description="Использование CPU")
    memory_usage: List[Dict[str, Any]] = Field(description="Использование памяти")
    disk_usage: List[Dict[str, Any]] = Field(description="Использование диска")
    network_traffic: List[Dict[str, Any]] = Field(description="Сетевой трафик")
    response_times: List[Dict[str, Any]] = Field(description="Время отклика")
    error_rates: List[Dict[str, Any]] = Field(description="Процент ошибок")
    metrics: List[SystemMetric] = Field(description="Детальные метрики")

class DocumentProcessing(BaseModel):
    """Обработка документов"""
    document_id: str
    document_type: str
    processing_time_ms: int
    status: str
    processed_at: datetime
    size_bytes: int

class DocumentAnalytics(BaseModel):
    """Аналитика по документам"""
    period: Dict[str, date]
    total_documents: int = Field(description="Общее количество документов")
    processed_documents: int = Field(description="Обработанные документы")
    failed_documents: int = Field(description="Неудачные обработки")
    processing_success_rate: float = Field(description="Процент успешной обработки")
    avg_processing_time_ms: float = Field(description="Среднее время обработки")
    documents_by_type: List[Dict[str, Any]] = Field(description="Документы по типам")
    processing_by_day: List[Dict[str, Any]] = Field(description="Обработка по дням")
    top_document_types: List[Dict[str, Any]] = Field(description="Топ типов документов")

class APIUsageRecord(BaseModel):
    """Запись использования API"""
    endpoint: str
    method: str
    status_code: int
    response_time_ms: int
    timestamp: datetime
    user_id: Optional[str]

class APIUsageStats(BaseModel):
    """Статистика использования API"""
    period: Dict[str, date]
    total_requests: int = Field(description="Общее количество запросов")
    successful_requests: int = Field(description="Успешные запросы")
    failed_requests: int = Field(description="Неудачные запросы")
    avg_response_time_ms: float = Field(description="Среднее время отклика")
    requests_by_endpoint: List[Dict[str, Any]] = Field(description="Запросы по эндпоинтам")
    requests_by_day: List[Dict[str, Any]] = Field(description="Запросы по дням")
    top_endpoints: List[Dict[str, Any]] = Field(description="Топ эндпоинтов")
    error_distribution: List[Dict[str, Any]] = Field(description="Распределение ошибок")

class ErrorRecord(BaseModel):
    """Запись об ошибке"""
    id: str
    execution_id: str
    workflow_id: str
    workflow_name: str
    node_name: str
    error_type: str
    error_message: str
    occurred_at: datetime
    resolved: bool

class ErrorAnalysis(BaseModel):
    """Анализ ошибок"""
    period: Dict[str, date]
    total_errors: int = Field(description="Общее количество ошибок")
    resolved_errors: int = Field(description="Решенные ошибки")
    unresolved_errors: int = Field(description="Нерешенные ошибки")
    errors_by_type: List[Dict[str, Any]] = Field(description="Ошибки по типам")
    errors_by_workflow: List[Dict[str, Any]] = Field(description="Ошибки по воркфлоу")
    errors_by_day: List[Dict[str, Any]] = Field(description="Ошибки по дням")
    top_error_messages: List[Dict[str, Any]] = Field(description="Топ сообщений об ошибках")
    error_trends: List[Dict[str, Any]] = Field(description="Тренды ошибок")
    errors: List[ErrorRecord] = Field(description="Записи об ошибках")

class PerformanceMetric(BaseModel):
    """Метрика производительности"""
    metric_name: str
    current_value: float
    previous_value: float
    change_percent: float
    trend: str  # "up", "down", "stable"

class PerformanceReport(BaseModel):
    """Отчет о производительности"""
    period: Dict[str, date]
    report_type: str = Field(description="Тип отчета")
    generated_at: datetime = Field(description="Время генерации")
    
    # Key Performance Indicators
    kpis: List[PerformanceMetric] = Field(description="Ключевые показатели")
    
    # Performance metrics
    workflow_performance: Dict[str, Any] = Field(description="Производительность воркфлоу")
    system_performance: Dict[str, Any] = Field(description="Производительность системы")
    user_performance: Dict[str, Any] = Field(description="Производительность пользователей")
    
    # Trends and insights
    trends: List[Dict[str, Any]] = Field(description="Тренды")
    insights: List[str] = Field(description="Инсайты")
    recommendations: List[str] = Field(description="Рекомендации")

class RealtimeDashboard(BaseModel):
    """Real-time дашборд"""
    timestamp: datetime = Field(description="Время обновления")
    active_workflows: int = Field(description="Активные воркфлоу")
    current_executions: int = Field(description="Текущие выполнения")
    success_rate_last_hour: float = Field(description="Процент успеха за последний час")
    avg_response_time_ms: float = Field(description="Среднее время отклика")
    active_users: int = Field(description="Активные пользователи")
    system_health: Dict[str, str] = Field(description="Здоровье системы")
    recent_errors: List[Dict[str, Any]] = Field(description="Недавние ошибки")
    resource_usage: Dict[str, float] = Field(description="Использование ресурсов")
