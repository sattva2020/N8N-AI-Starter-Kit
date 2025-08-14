#!/usr/bin/env python3
"""
Workflows Manager - Веб-интерфейс для управления импортом workflow'ов
Интеграция с репозиторием Zie619/n8n-workflows
"""

import os
import json
import requests
import logging
import re
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, validator
import uvicorn
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Инициализация rate limiter
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(title="Workflows Manager", version="1.0.0")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене заменить на конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer(auto_error=False)

# Модели данных
class WorkflowImport(BaseModel):
    workflow_id: str
    name: str
    category: Optional[str] = None
    
    @validator('workflow_id')
    def validate_workflow_id(cls, v):
        # Проверяем, что filename содержит только безопасные символы
        if not re.match(r'^[a-zA-Z0-9_\-\.,]+\.json$', v):
            raise ValueError('Invalid workflow filename')
        return v

class ImportResult(BaseModel):
    success: bool
    message: str
    imported_count: int = 0
    failed_count: int = 0

# Конфигурация
WORKFLOWS_DOC_URL = os.getenv("WORKFLOWS_DOC_URL", "http://workflows-doc:8000")
N8N_URL = os.getenv("N8N_URL", "http://n8n:5678")
N8N_API_KEY = os.getenv("N8N_API_KEY")
WORKFLOWS_MANAGER_API_KEY = os.getenv("WORKFLOWS_MANAGER_API_KEY", "")

def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)) -> bool:
    """Проверка API ключа для аутентификации"""
    if not WORKFLOWS_MANAGER_API_KEY:
        return True  # Если ключ не настроен, пропускаем аутентификацию
    
    if not credentials:
        raise HTTPException(status_code=401, detail="API key required")
    
    if credentials.credentials != WORKFLOWS_MANAGER_API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API key")
    
    return True

class WorkflowsManager:
    def __init__(self):
        self.session = requests.Session()
        if N8N_API_KEY:
            self.session.headers.update({"X-N8N-API-KEY": N8N_API_KEY})
    
    def get_workflows_from_doc(self, search: str = None, category: str = None) -> List[Dict]:
        """Получение списка workflow'ов из веб-сервиса документации"""
        try:
            url = f"{WORKFLOWS_DOC_URL}/api/workflows"
            params = {}
            if search:
                # Валидация поискового запроса
                if len(search) > 100:
                    search = search[:100]
                params["q"] = search
            if category:
                # Валидация категории
                if not re.match(r'^[a-zA-Z0-9_\-\s]+$', category):
                    category = None
                else:
                    params["category"] = category
            
            response = self.session.get(url, params=params, timeout=10)
            if response.status_code == 200:
                return response.json().get("workflows", [])
            else:
                logger.warning(f"Ошибка получения workflow'ов: {response.status_code}")
                return []
        except Exception as e:
            logger.error(f"Ошибка подключения к workflows-doc: {e}")
            return []
    
    def get_categories(self) -> List[str]:
        """Получение списка категорий"""
        try:
            response = self.session.get(f"{WORKFLOWS_DOC_URL}/api/categories", timeout=10)
            if response.status_code == 200:
                return response.json().get("categories", [])
            return []
        except Exception as e:
            logger.error(f"Ошибка получения категорий: {e}")
            return []
    
    def import_workflow_to_n8n(self, workflow_data: Dict) -> bool:
        """Импорт workflow в n8n"""
        try:
            # Получаем JSON файл workflow
            filename = workflow_data.get("filename")
            if not filename:
                return False
            
            # Валидация имени файла для предотвращения path traversal
            if not re.match(r'^[a-zA-Z0-9_\-\.,]+\.json$', filename):
                logger.error(f"Invalid filename: {filename}")
                return False
            
            # Загружаем workflow из файла
            workflow_file_path = f"/workflows/{filename}"
            
            # Дополнительная проверка пути
            if not os.path.exists(workflow_file_path) or not os.path.isfile(workflow_file_path):
                logger.error(f"Файл workflow не найден: {workflow_file_path}")
                return False
            
            # Проверяем, что файл находится в разрешенной директории
            real_path = os.path.realpath(workflow_file_path)
            allowed_path = os.path.realpath("/workflows")
            if not real_path.startswith(allowed_path):
                logger.error(f"Path traversal attempt: {workflow_file_path}")
                return False
            
            with open(workflow_file_path, 'r', encoding='utf-8') as f:
                workflow_json = json.load(f)
            
            # Валидация JSON структуры
            if not isinstance(workflow_json, dict):
                logger.error(f"Invalid workflow JSON structure: {filename}")
                return False
            
            # Импортируем в n8n
            response = self.session.post(
                f"{N8N_URL}/rest/workflows",
                json=workflow_json,
                timeout=30
            )
            
            if response.status_code in [200, 201]:
                logger.info(f"Workflow {filename} успешно импортирован")
                return True
            else:
                logger.error(f"Ошибка импорта {filename}: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"Ошибка импорта workflow: {e}")
            return False

# Инициализация менеджера
manager = WorkflowsManager()

@app.get("/", response_class=HTMLResponse)
@limiter.limit("10/minute")
async def index(request: Request):
    """Главная страница"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Workflows Manager</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 1200px; margin: 0 auto; }
            .header { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .search-box { margin: 20px 0; }
            .search-box input { padding: 10px; width: 300px; margin-right: 10px; }
            .search-box button { padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
            .workflows-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
            .workflow-card { border: 1px solid #ddd; padding: 15px; border-radius: 8px; }
            .workflow-card h3 { margin: 0 0 10px 0; }
            .workflow-card .category { color: #666; font-size: 0.9em; }
            .workflow-card .import-btn { background: #28a745; color: white; border: none; padding: 5px 10px; border-radius: 4px; cursor: pointer; margin-top: 10px; }
            .stats { background: #e9ecef; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
            .error { color: #dc3545; background: #f8d7da; padding: 10px; border-radius: 4px; margin: 10px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 Workflows Manager</h1>
                <p>Управление импортом workflow'ов из репозитория Zie619/n8n-workflows</p>
            </div>
            
            <div class="search-box">
                <input type="text" id="searchInput" placeholder="Поиск workflow'ов..." maxlength="100">
                <button onclick="searchWorkflows()">🔍 Поиск</button>
                <button onclick="loadWorkflows()">📋 Все workflow'ы</button>
            </div>
            
            <div class="stats" id="stats">
                <h3>📊 Статистика</h3>
                <div id="statsContent">Загрузка...</div>
            </div>
            
            <div class="workflows-grid" id="workflowsGrid">
                <div>Загрузка workflow'ов...</div>
            </div>
        </div>
        
        <script>
            async function loadWorkflows() {
                try {
                    const response = await fetch('/api/workflows');
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }
                    const data = await response.json();
                    displayWorkflows(data.workflows);
                    updateStats(data.stats);
                } catch (error) {
                    console.error('Ошибка загрузки:', error);
                    document.getElementById('workflowsGrid').innerHTML = 
                        '<div class="error">Ошибка загрузки workflow\'ов</div>';
                }
            }
            
            async function searchWorkflows() {
                const query = document.getElementById('searchInput').value.trim();
                if (!query) return loadWorkflows();
                
                try {
                    const response = await fetch(`/api/workflows?q=${encodeURIComponent(query)}`);
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }
                    const data = await response.json();
                    displayWorkflows(data.workflows);
                    updateStats(data.stats);
                } catch (error) {
                    console.error('Ошибка поиска:', error);
                    document.getElementById('workflowsGrid').innerHTML = 
                        '<div class="error">Ошибка поиска workflow\'ов</div>';
                }
            }
            
            function displayWorkflows(workflows) {
                const grid = document.getElementById('workflowsGrid');
                grid.innerHTML = '';
                
                if (!workflows || workflows.length === 0) {
                    grid.innerHTML = '<div>Workflow\'ы не найдены</div>';
                    return;
                }
                
                workflows.forEach(workflow => {
                    const card = document.createElement('div');
                    card.className = 'workflow-card';
                    const safeFilename = workflow.filename ? workflow.filename.replace(/[^a-zA-Z0-9_\-\.,]/g, '') : '';
                    card.innerHTML = `
                        <h3>${workflow.name || workflow.filename || 'Без названия'}</h3>
                        <div class="category">${workflow.category || 'Без категории'}</div>
                        <div>${workflow.description || 'Описание отсутствует'}</div>
                        <button class="import-btn" onclick="importWorkflow('${safeFilename}')">
                            📥 Импортировать
                        </button>
                    `;
                    grid.appendChild(card);
                });
            }
            
            function updateStats(stats) {
                const statsContent = document.getElementById('statsContent');
                statsContent.innerHTML = `
                    <div>Всего: ${stats.total || 0}</div>
                    <div>Активных: ${stats.active || 0}</div>
                    <div>Категорий: ${stats.categories || 0}</div>
                `;
            }
            
            async function importWorkflow(filename) {
                if (!filename || !filename.match(/^[a-zA-Z0-9_\-\.,]+\.json$/)) {
                    alert('Некорректное имя файла');
                    return;
                }
                
                try {
                    const response = await fetch('/api/import', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({
                            workflow_id: filename,
                            name: filename.replace('.json', '')
                        })
                    });
                    
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }
                    
                    const result = await response.json();
                    alert(result.message);
                } catch (error) {
                    console.error('Ошибка импорта:', error);
                    alert('Ошибка импорта workflow');
                }
            }
            
            // Загружаем workflow'ы при загрузке страницы
            loadWorkflows();
        </script>
    </body>
    </html>
    """

@app.get("/api/workflows")
@limiter.limit("30/minute")
async def get_workflows(request: Request, q: str = None, category: str = None):
    """API для получения workflow'ов"""
    workflows = manager.get_workflows_from_doc(q, category)
    categories = manager.get_categories()
    
    # Получаем статистику
    stats = {
        "total": len(workflows),
        "categories": len(categories),
        "active": len([w for w in workflows if w.get("active", False)])
    }
    
    return {
        "workflows": workflows,
        "stats": stats,
        "categories": categories
    }

@app.get("/api/categories")
@limiter.limit("10/minute")
async def get_categories(request: Request):
    """API для получения категорий"""
    return {"categories": manager.get_categories()}

@app.post("/api/import")
@limiter.limit("5/minute")
async def import_workflow(request: Request, workflow: WorkflowImport, background_tasks: BackgroundTasks):
    """API для импорта workflow"""
    try:
        # Получаем данные workflow
        workflows = manager.get_workflows_from_doc()
        target_workflow = next((w for w in workflows if w.get("filename") == workflow.workflow_id), None)
        
        if not target_workflow:
            raise HTTPException(status_code=404, detail="Workflow не найден")
        
        # Импортируем в фоновом режиме
        background_tasks.add_task(manager.import_workflow_to_n8n, target_workflow)
        
        return ImportResult(
            success=True,
            message=f"Workflow '{workflow.name}' поставлен в очередь на импорт"
        )
        
    except Exception as e:
        logger.error(f"Ошибка импорта: {e}")
        return ImportResult(
            success=False,
            message=f"Ошибка импорта: {str(e)}"
        )

@app.get("/health")
async def health_check():
    """Health check"""
    return {"status": "healthy", "service": "workflows-manager"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8004)
