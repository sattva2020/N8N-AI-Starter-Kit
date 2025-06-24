# 🌐 Web Interface Service
# ========================
# FastAPI + Jinja2 веб-интерфейс для n8n-ai-starter-kit

import os
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime
import asyncio
import aiohttp

import uvicorn
from fastapi import FastAPI, HTTPException, Request, Form, UploadFile, File
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Инициализация FastAPI приложения
app = FastAPI(
    title="Web Interface Service",
    description="Веб-интерфейс для управления документами и поиска в n8n-ai-starter-kit",
    version="1.2.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Статические файлы и шаблоны
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Конфигурация
DOCUMENT_PROCESSOR_URL = os.getenv("DOCUMENT_PROCESSOR_URL", "http://document-processor:8001")

# Модели Pydantic
class SearchRequest(BaseModel):
    query: str
    limit: int = 10

class DocumentInfo(BaseModel):
    id: str
    title: str
    content: str
    metadata: Optional[Dict[str, Any]] = None
    created_at: Optional[str] = None

# Health Check
@app.get("/health")
async def health_check():
    """Проверка состояния сервиса"""
    try:
        # Проверяем подключение к document-processor
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{DOCUMENT_PROCESSOR_URL}/health") as response:
                dp_status = "ok" if response.status == 200 else "error"
    except:
        dp_status = "error"
    
    return {
        "status": "healthy" if dp_status == "ok" else "unhealthy",
        "version": "1.2.0",
        "services": {
            "document_processor": dp_status,
            "templates": "ok",
            "static_files": "ok"
        }
    }

# Основные страницы
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Главная страница"""
    return templates.TemplateResponse("index.html", {
        "request": request,
        "title": "N8N AI Starter Kit",
        "version": "1.2.0"
    })

@app.get("/upload", response_class=HTMLResponse)
async def upload_page(request: Request):
    """Страница загрузки документов"""
    return templates.TemplateResponse("upload.html", {
        "request": request,
        "title": "Загрузка документов"
    })

@app.get("/search", response_class=HTMLResponse)
async def search_page(request: Request):
    """Страница поиска"""
    return templates.TemplateResponse("search.html", {
        "request": request,
        "title": "Поиск документов"
    })

@app.get("/analytics", response_class=HTMLResponse)
async def analytics_page(request: Request):
    """Страница аналитики"""
    return templates.TemplateResponse("analytics.html", {
        "request": request,
        "title": "Аналитика"
    })

@app.get("/documents", response_class=HTMLResponse)
async def documents_page(request: Request):
    """Страница управления документами"""
    return templates.TemplateResponse("documents.html", {
        "request": request,
        "title": "Управление документами"
    })

# API endpoints
@app.post("/api/upload")
async def upload_document(file: UploadFile = File(...)):
    """API для загрузки документов"""
    try:
        # Проксируем запрос к document-processor
        async with aiohttp.ClientSession() as session:
            data = aiohttp.FormData()
            data.add_field('file', await file.read(), 
                          filename=file.filename, 
                          content_type=file.content_type)
            
            async with session.post(f"{DOCUMENT_PROCESSOR_URL}/documents/upload", 
                                  data=data) as response:
                result = await response.json()
                return result
                
    except Exception as e:
        logger.error(f"Ошибка загрузки файла: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/search")
async def search_documents(request: SearchRequest):
    """API для поиска документов"""
    try:
        # Проксируем запрос к document-processor
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{DOCUMENT_PROCESSOR_URL}/documents/search",
                json=request.dict()
            ) as response:
                result = await response.json()
                return result
                
    except Exception as e:
        logger.error(f"Ошибка поиска: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/documents")
async def list_documents():
    """API для получения списка документов"""
    try:
        # Получаем документы от document-processor
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{DOCUMENT_PROCESSOR_URL}/documents") as response:
                if response.status == 200:
                    data = await response.json()
                    return data
                else:
                    # Если сервис недоступен, возвращаем тестовые данные
                    logger.warning("Document processor недоступен, используем тестовые данные")
                    documents = [
                        {
                            "id": "doc_1",
                            "title": "Тестовый документ 1",
                            "content": "Содержимое первого документа о машинном обучении...",
                            "metadata": {"type": "text", "size": 1024},
                            "created_at": datetime.now().isoformat()
                        },
                        {
                            "id": "doc_2", 
                            "title": "Тестовый документ 2",
                            "content": "Содержимое второго документа об искусственном интеллекте...",
                            "metadata": {"type": "pdf", "size": 2048},
                            "created_at": datetime.now().isoformat()
                        }
                    ]
                    
                    return {
                        "documents": documents,
                        "total": len(documents)
                    }
        
    except Exception as e:
        logger.error(f"Ошибка получения документов: {e}")
        # Возвращаем пустой список в случае ошибки
        return {
            "documents": [],
            "total": 0,
            "error": str(e)
        }

@app.delete("/api/documents/{document_id}")
async def delete_document(document_id: str):
    """API для удаления документа"""
    try:
        # Проксируем запрос к document-processor
        async with aiohttp.ClientSession() as session:
            async with session.delete(
                f"{DOCUMENT_PROCESSOR_URL}/documents/{document_id}"
            ) as response:
                result = await response.json()
                return result
                
    except Exception as e:
        logger.error(f"Ошибка удаления документа: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/analytics")
async def get_analytics():
    """API для получения аналитики"""
    try:
        # Проксируем запрос к document-processor
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{DOCUMENT_PROCESSOR_URL}/metrics") as response:
                metrics = await response.json()
                
        # Дополнительная аналитика
        analytics = {
            "metrics": metrics,
            "charts": {
                "documents_by_type": {
                    "text": 5,
                    "pdf": 3,
                    "docx": 2
                },
                "searches_by_day": [
                    {"date": "2024-06-20", "searches": 15},
                    {"date": "2024-06-21", "searches": 23},
                    {"date": "2024-06-22", "searches": 18},
                    {"date": "2024-06-23", "searches": 31},
                    {"date": "2024-06-24", "searches": 28}
                ],
                "popular_queries": [
                    {"query": "машинное обучение", "count": 45},
                    {"query": "искусственный интеллект", "count": 38},
                    {"query": "нейронные сети", "count": 29},
                    {"query": "обработка данных", "count": 22},
                    {"query": "векторный поиск", "count": 18}
                ]
            }
        }
        
        return analytics
        
    except Exception as e:
        logger.error(f"Ошибка получения аналитики: {e}")
        return {
            "metrics": {"error": str(e)},
            "charts": {}
        }

@app.get("/api/status")
async def get_status():
    """API для получения статуса системы"""
    try:
        # Проверяем статус document-processor
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{DOCUMENT_PROCESSOR_URL}/status") as response:
                dp_status = await response.json()
        
        return {
            "web_interface": {
                "service": "web-interface",
                "status": "running",
                "version": "1.2.0",
                "timestamp": datetime.now().isoformat()
            },
            "document_processor": dp_status
        }
        
    except Exception as e:
        logger.error(f"Ошибка получения статуса: {e}")
        return {
            "web_interface": {
                "service": "web-interface", 
                "status": "running",
                "version": "1.2.0",
                "timestamp": datetime.now().isoformat()
            },
            "document_processor": {
                "status": "error",
                "error": str(e)
            }
        }

# Дополнительные служебные endpoints
@app.get("/api/notifications")
async def get_notifications():
    """API для получения уведомлений"""
    notifications = [
        {
            "id": "1",
            "type": "info",
            "message": "Система готова к работе",
            "timestamp": datetime.now().isoformat()
        },
        {
            "id": "2", 
            "type": "success",
            "message": "Модели загружены успешно",
            "timestamp": datetime.now().isoformat()
        }
    ]
    
    return {"notifications": notifications}

@app.post("/api/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str):
    """API для отметки уведомления как прочитанного"""
    return {
        "notification_id": notification_id,
        "status": "read",
        "timestamp": datetime.now().isoformat()
    }

# Обработчики ошибок
@app.exception_handler(404)
async def not_found_handler(request: Request, exc: HTTPException):
    """Обработчик 404 ошибок"""
    return templates.TemplateResponse("error.html", {
        "request": request,
        "title": "Страница не найдена",
        "error_code": 404,
        "error_message": "Запрашиваемая страница не найдена"
    }, status_code=404)

@app.exception_handler(500)
async def server_error_handler(request: Request, exc: HTTPException):
    """Обработчик 500 ошибок"""
    return templates.TemplateResponse("error.html", {
        "request": request,
        "title": "Внутренняя ошибка сервера",
        "error_code": 500,
        "error_message": "Произошла внутренняя ошибка сервера"
    }, status_code=500)

if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8002,
        reload=True,
        log_level="info"
    )
