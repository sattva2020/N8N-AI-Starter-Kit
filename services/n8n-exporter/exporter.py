#!/usr/bin/env python3
"""
N8N Metrics Exporter для Prometheus
Собирает метрики с N8N API и экспортирует их в формате Prometheus
"""

import time
import logging
import os
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import requests
from prometheus_client import start_http_server, Gauge, Counter, Histogram, Info
from prometheus_client.core import CollectorRegistry

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class N8NMetricsExporter:
    """Экспортер метрик N8N для Prometheus"""
    
    def __init__(self):
        self.n8n_url = os.getenv('N8N_API_URL', 'http://n8n:5678')
        self.api_key = os.getenv('N8N_API_KEY', '')
        self.metrics_port = int(os.getenv('METRICS_PORT', '9101'))
        self.scrape_interval = int(os.getenv('SCRAPE_INTERVAL', '30'))
        
        # Registry для метрик
        self.registry = CollectorRegistry()
        
        # Метрики N8N
        self.n8n_info = Info(
            'n8n_info', 
            'N8N instance information', 
            registry=self.registry
        )
        
        self.workflows_total = Gauge(
            'n8n_workflows_total', 
            'Total number of workflows', 
            registry=self.registry
        )
        
        self.workflows_active = Gauge(
            'n8n_workflows_active', 
            'Number of active workflows', 
            registry=self.registry
        )
        
        self.executions_total = Counter(
            'n8n_workflow_executions_total', 
            'Total workflow executions',
            ['workflow_name', 'status'],
            registry=self.registry
        )
        
        self.executions_failed_total = Counter(
            'n8n_workflow_executions_failed_total', 
            'Failed workflow executions',
            ['workflow_name', 'error_type'],
            registry=self.registry
        )
        
        self.execution_duration = Histogram(
            'n8n_workflow_execution_duration_ms',
            'Workflow execution duration in milliseconds',
            ['workflow_name'],
            registry=self.registry,
            buckets=[100, 500, 1000, 2000, 5000, 10000, 30000, 60000, 120000]
        )
        
        self.nodes_total = Gauge(
            'n8n_nodes_total',
            'Total number of nodes',
            ['node_type'],
            registry=self.registry
        )
        
        self.credentials_total = Gauge(
            'n8n_credentials_total',
            'Total number of credentials',
            ['credential_type'],
            registry=self.registry
        )
        
        # Метрики производительности API
        self.api_requests_total = Counter(
            'n8n_api_requests_total',
            'Total API requests',
            ['endpoint', 'method', 'status'],
            registry=self.registry
        )
        
        self.api_request_duration = Histogram(
            'n8n_api_request_duration_ms',
            'API request duration in milliseconds',
            ['endpoint'],
            registry=self.registry,
            buckets=[10, 50, 100, 500, 1000, 2000, 5000]
        )
        
        # Headers для API запросов
        self.headers = {
            'X-N8N-API-KEY': self.api_key,
            'Content-Type': 'application/json'
        } if self.api_key else {'Content-Type': 'application/json'}
        
    def make_api_request(self, endpoint: str, method: str = 'GET') -> Optional[Dict]:
        """Выполняет API запрос к N8N"""
        url = f"{self.n8n_url}/api/v1/{endpoint}"
        
        start_time = time.time()
        status = 'success'
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=self.headers, timeout=10)
            else:
                response = requests.request(method, url, headers=self.headers, timeout=10)
                
            response.raise_for_status()
            duration = (time.time() - start_time) * 1000
            
            # Записываем метрики API
            self.api_requests_total.labels(
                endpoint=endpoint, 
                method=method, 
                status=response.status_code
            ).inc()
            
            self.api_request_duration.labels(endpoint=endpoint).observe(duration)
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            duration = (time.time() - start_time) * 1000
            status = 'error'
            
            self.api_requests_total.labels(
                endpoint=endpoint, 
                method=method, 
                status='error'
            ).inc()
            
            self.api_request_duration.labels(endpoint=endpoint).observe(duration)
            
            logger.error(f"API request failed for {endpoint}: {e}")
            return None
    
    def collect_workflow_metrics(self):
        """Собирает метрики workflows"""
        try:
            # Получаем список workflows
            workflows_data = self.make_api_request('workflows')
            if not workflows_data:
                return
                
            workflows = workflows_data.get('data', [])
            total_workflows = len(workflows)
            active_workflows = sum(1 for w in workflows if w.get('active', False))
            
            self.workflows_total.set(total_workflows)
            self.workflows_active.set(active_workflows)
            
            logger.info(f"Collected workflow metrics: {total_workflows} total, {active_workflows} active")
            
            # Собираем статистику по типам узлов
            node_types = {}
            for workflow in workflows:
                for node in workflow.get('nodes', []):
                    node_type = node.get('type', 'unknown')
                    node_types[node_type] = node_types.get(node_type, 0) + 1
            
            # Обновляем метрики узлов
            for node_type, count in node_types.items():
                self.nodes_total.labels(node_type=node_type).set(count)
                
        except Exception as e:
            logger.error(f"Error collecting workflow metrics: {e}")
    
    def collect_execution_metrics(self):
        """Собирает метрики выполнения workflows"""
        try:
            # Получаем последние выполнения (за последний час)
            end_time = datetime.now()
            start_time = end_time - timedelta(hours=1)
            
            params = {
                'startedAfter': start_time.isoformat(),
                'startedBefore': end_time.isoformat(),
                'limit': 1000
            }
            
            executions_data = self.make_api_request('executions')
            if not executions_data:
                return
                
            executions = executions_data.get('data', [])
            
            # Анализируем выполнения
            for execution in executions:
                workflow_name = execution.get('workflowData', {}).get('name', 'unknown')
                status = execution.get('status', 'unknown')
                start_time_str = execution.get('startedAt')
                stop_time_str = execution.get('stoppedAt')
                
                # Обновляем счетчики
                self.executions_total.labels(
                    workflow_name=workflow_name, 
                    status=status
                ).inc()
                
                # Если выполнение провалилось
                if status == 'error':
                    error_type = execution.get('data', {}).get('resultData', {}).get('error', {}).get('name', 'unknown')
                    self.executions_failed_total.labels(
                        workflow_name=workflow_name,
                        error_type=error_type
                    ).inc()
                
                # Рассчитываем продолжительность
                if start_time_str and stop_time_str:
                    try:
                        start_dt = datetime.fromisoformat(start_time_str.replace('Z', '+00:00'))
                        stop_dt = datetime.fromisoformat(stop_time_str.replace('Z', '+00:00'))
                        duration_ms = (stop_dt - start_dt).total_seconds() * 1000
                        
                        self.execution_duration.labels(
                            workflow_name=workflow_name
                        ).observe(duration_ms)
                    except Exception as e:
                        logger.warning(f"Could not parse execution times: {e}")
            
            logger.info(f"Collected execution metrics for {len(executions)} executions")
            
        except Exception as e:
            logger.error(f"Error collecting execution metrics: {e}")
    
    def collect_credentials_metrics(self):
        """Собирает метрики учетных данных"""
        try:
            credentials_data = self.make_api_request('credentials')
            if not credentials_data:
                return
                
            credentials = credentials_data.get('data', [])
            
            # Группируем по типам
            cred_types = {}
            for cred in credentials:
                cred_type = cred.get('type', 'unknown')
                cred_types[cred_type] = cred_types.get(cred_type, 0) + 1
            
            # Обновляем метрики
            for cred_type, count in cred_types.items():
                self.credentials_total.labels(credential_type=cred_type).set(count)
                
            logger.info(f"Collected credentials metrics: {len(credentials)} total")
            
        except Exception as e:
            logger.error(f"Error collecting credentials metrics: {e}")
    
    def collect_system_info(self):
        """Собирает системную информацию N8N"""
        try:
            # Пробуем получить системную информацию
            # Примечание: не все версии N8N имеют этот endpoint
            info_data = self.make_api_request('me')
            if info_data:
                # Устанавливаем базовую информацию
                self.n8n_info.info({
                    'version': info_data.get('version', 'unknown'),
                    'instance_id': info_data.get('id', 'unknown'),
                    'exporter_version': '1.0.0'
                })
            else:
                # Fallback информация
                self.n8n_info.info({
                    'version': 'unknown',
                    'instance_id': 'unknown',
                    'exporter_version': '1.0.0'
                })
                
        except Exception as e:
            logger.error(f"Error collecting system info: {e}")
    
    async def collect_all_metrics(self):
        """Собирает все метрики"""
        logger.info("Starting metrics collection...")
        
        self.collect_system_info()
        self.collect_workflow_metrics()
        self.collect_execution_metrics()
        self.collect_credentials_metrics()
        
        logger.info("Metrics collection completed")
    
    async def start_metrics_server(self):
        """Запускает HTTP сервер для метрик"""
        try:
            start_http_server(self.metrics_port, registry=self.registry)
            logger.info(f"Metrics server started on port {self.metrics_port}")
            
            # Основной цикл сбора метрик
            while True:
                await self.collect_all_metrics()
                await asyncio.sleep(self.scrape_interval)
                
        except Exception as e:
            logger.error(f"Error starting metrics server: {e}")
            raise

def health_check():
    """Простая проверка здоровья"""
    return "OK"

async def main():
    """Главная функция"""
    exporter = N8NMetricsExporter()
    
    logger.info("Starting N8N Metrics Exporter...")
    logger.info(f"N8N URL: {exporter.n8n_url}")
    logger.info(f"Metrics port: {exporter.metrics_port}")
    logger.info(f"Scrape interval: {exporter.scrape_interval}s")
    
    try:
        await exporter.start_metrics_server()
    except KeyboardInterrupt:
        logger.info("Shutting down exporter...")
    except Exception as e:
        logger.error(f"Exporter error: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())
