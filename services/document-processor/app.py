# 📄 Document Processor Service
# =============================
# FastAPI приложение для обработки документов и векторных операций

import os
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime
import asyncio
import tempfile
import shutil
import time

import uvicorn
from fastapi import FastAPI, HTTPException, UploadFile, File, Depends, BackgroundTasks, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ML и Vector Processing - АКТИВИРОВАНЫ
import pandas as pd
import numpy as np
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient, models
from qdrant_client.http import models as qdrant_models
import psycopg2
from psycopg2.extras import RealDictCursor
import aiohttp
import asyncpg

import json

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Инициализация FastAPI приложения
app = FastAPI(
    title="Document Processor Service",
    description="Сервис для обработки документов и векторных операций в n8n-ai-starter-kit",
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

# Модели Pydantic
class DocumentModel(BaseModel):
    title: str
    content: str
    metadata: Optional[Dict[str, Any]] = None
    categories: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    version: Optional[str] = None
    created_at: Optional[str] = None
    last_modified_at: Optional[str] = None

class DocumentInfo(BaseModel):
    id: str
    title: str
    content: str
    metadata: Optional[Dict[str, Any]] = None
    categories: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    version: Optional[str] = None
    created_at: Optional[str] = None
    last_modified_at: Optional[str] = None

class SearchRequest(BaseModel):
    query: str = Field(..., description="Поисковый запрос")
    limit: int = Field(default=5, ge=1, le=100, description="Количество результатов")
    threshold: float = Field(default=0.05, ge=0.0, le=1.0, description="Порог релевантности")
    categories: Optional[List[str]] = Field(None, description="Список категорий для фильтрации")
    tags: Optional[List[str]] = Field(None, description="Список тегов для фильтрации")

class SearchResult(BaseModel):
    document_id: str
    title: str
    content_preview: str
    similarity_score: float
    metadata: dict

class SearchResponse(BaseModel):
    query: str
    results: List[SearchResult]
    total_found: int
    search_time_ms: float

class ProcessRequest(BaseModel):
    document_id: str
    force_reprocess: bool = False

class HealthResponse(BaseModel):
    status: str
    version: str
    services: Dict[str, str]

# Глобальные переменные для инициализации
embedding_model = None
qdrant_client = None
db_pool = None

# Конфигурация из переменных окружения
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://n8n:change_this_secure_password_123@postgres:5432/n8n")
QDRANT_HOST = os.getenv("QDRANT_HOST", "qdrant")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", "6333"))
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")

@app.on_event("startup")
async def startup_event():
    """Инициализация сервисов при запуске"""
    global embedding_model, qdrant_client, db_pool
    
    try:
        logger.info("Инициализация Document Processor Service...")
        # Инициализация модели эмбеддингов - АКТИВИРОВАНА
        logger.info(f"Загрузка модели эмбеддингов: {EMBEDDING_MODEL}")
        embedding_model = SentenceTransformer(EMBEDDING_MODEL)
        
        # Инициализация Qdrant клиента - АКТИВИРОВАНА
        logger.info("Инициализация Qdrant клиента...")
        qdrant_host = os.getenv("QDRANT_HOST", "qdrant")
        qdrant_port = int(os.getenv("QDRANT_PORT", "6333"))
        qdrant_client = QdrantClient(host=qdrant_host, port=qdrant_port)
        
        # Создание коллекции для документов если не существует - АКТИВИРОВАНО
        try:
            qdrant_client.create_collection(
                collection_name="documents",
                vectors_config=models.VectorParams(
                    size=384,  # Размер векторов для all-MiniLM-L6-v2
                    distance=models.Distance.COSINE
                )
            )
            logger.info("Создана коллекция 'documents' в Qdrant")
        except Exception as e:
            logger.info(f"Коллекция 'documents' уже существует: {e}")
        
        # Инициализация пула подключений к БД
        logger.info("Инициализация подключения к PostgreSQL...")
        db_pool = await asyncpg.create_pool(DATABASE_URL)
        
        logger.info("Document Processor Service успешно инициализирован!")
        
    except Exception as e:
        logger.error(f"Ошибка инициализации: {e}")
        # Не поднимаем исключение, чтобы сервис мог запуститься частично
        logger.warning("Сервис запущен в режиме ограниченной функциональности")

@app.on_event("shutdown")
async def shutdown_event():
    """Очистка ресурсов при завершении"""
    global db_pool
    
    if db_pool:
        await db_pool.close()
    
    logger.info("Document Processor Service остановлен")

# Health Check
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Проверка состояния сервиса"""
    services = {
        "embedding_model": "ok" if embedding_model else "error",
        "qdrant_client": "ok" if qdrant_client else "error", 
        "database": "ok" if db_pool else "error"
    }
    
    status = "healthy" if all(s == "ok" for s in services.values()) else "unhealthy"
    
    return HealthResponse(
        status=status,
        version="1.2.0",
        services=services
    )

# Основные endpoints
@app.get("/")
async def root():
    """Корневой endpoint"""
    return {
        "service": "Document Processor",
        "version": "1.2.0",
        "status": "running",
        "docs": "/docs"
    }

@app.post("/documents/upload")
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    metadata: Optional[str] = Form(None),
    categories: Optional[str] = Form(None),
    tags: Optional[str] = Form(None)
):
    """Загрузка и обработка документа"""
    try:
        # Проверка типа файла
        allowed_types = ["text/plain", "application/pdf", "application/msword"]
        if file.content_type not in allowed_types:
            raise HTTPException(
                status_code=400, 
                detail=f"Неподдерживаемый тип файла: {file.content_type}"
            )
        
        # Сохранение временного файла
        with tempfile.NamedTemporaryFile(delete=False, suffix=f"_{file.filename}") as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_file_path = tmp_file.name
        
        # Добавление задачи в фон
        background_tasks.add_task(process_document_async, tmp_file_path, file.filename, metadata, categories, tags)
        
        return {
            "message": "Документ принят к обработке",
            "filename": file.filename,
            "size": len(content),
            "content_type": file.content_type
        }
        
    except Exception as e:
        logger.error(f"Ошибка загрузки документа: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# === SEARCH ENDPOINTS ===

@app.post("/documents/search", response_model=SearchResponse)
async def search_documents(request: SearchRequest):
    """Семантический поиск по документам"""
    start_time = time.time()
    
    try:
        if not embedding_model:
            raise HTTPException(status_code=503, detail="Модель эмбеддингов не инициализирована")
        
        if not qdrant_client:
            raise HTTPException(status_code=503, detail="Qdrant клиент не инициализирован")
        
        # Создание эмбеддинга для поискового запроса
        logger.info(f"Поиск по запросу: '{request.query}'")
        query_embedding = embedding_model.encode([request.query])[0].tolist()
        
        # Поиск в Qdrant
        # Формирование фильтра для Qdrant
        qdrant_filter = models.Filter(must=[])
        if request.categories:
            qdrant_filter.must.append(models.FieldCondition(
                key="categories",
                match=models.MatchAny(any=request.categories)
            ))
        if request.tags:
            qdrant_filter.must.append(models.FieldCondition(
                key="tags",
                match=models.MatchAny(any=request.tags)
            ))

        search_results = qdrant_client.search(
            collection_name="documents",
            query_vector=query_embedding,
            query_filter=qdrant_filter if qdrant_filter.must else None,
            limit=request.limit,
            score_threshold=request.threshold
        )
        
        # Формирование результатов
        results = []
        for result in search_results:
            # Получение метаданных из payload
            payload = result.payload or {}
            
            # Создание превью контента (первые 200 символов)
            content = payload.get("content", "")
            content_preview = content[:200] + "..." if len(content) > 200 else content
            
            search_result = SearchResult(
                document_id=str(result.id),
                title=payload.get("title", "Без названия"),
                content_preview=content_preview,
                similarity_score=round(result.score, 4),
                metadata=payload.get("metadata", {})
            )
            results.append(search_result)
        
        search_time = (time.time() - start_time) * 1000  # в миллисекундах
        
        logger.info(f"Поиск завершен: найдено {len(results)} документов за {search_time:.2f}ms")
        
        return SearchResponse(
            query=request.query,
            results=results,
            total_found=len(results),
            search_time_ms=round(search_time, 2)
        )
        
    except Exception as e:
        logger.error(f"Ошибка поиска: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка поиска: {str(e)}")

@app.post("/documents/process")
async def process_document(request: ProcessRequest):
    """Обработка документа по ID"""
    try:
        # Placeholder для обработки документа
        logger.info(f"Обработка документа: {request.document_id}")
        
        return {
            "document_id": request.document_id,
            "status": "processed",
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Ошибка обработки документа: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/documents/{document_id}")
async def get_document(document_id: str):
    """Получение документа по ID"""
    try:
        if not qdrant_client:
            raise HTTPException(status_code=503, detail="Qdrant клиент не инициализирован")
        
        # Получение документа из Qdrant
        try:
            document_id_int = int(document_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Неверный формат ID документа")
        
        result = qdrant_client.retrieve(
            collection_name="documents",
            ids=[document_id_int]
        )
        
        if not result:
            raise HTTPException(status_code=404, detail="Документ не найден")
        
        document = result[0]
        payload = document.payload or {}
        
        return {
            "document_id": str(document.id),
            "title": payload.get("title", "Без названия"),
            "content": payload.get("content", ""),
            "metadata": payload.get("metadata", {}),
            "size": payload.get("size", 0)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка получения документа: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка получения документа: {str(e)}")

@app.delete("/documents/{document_id}")
async def delete_document(document_id: str):
    """Удаление документа"""
    try:
        if not qdrant_client:
            raise HTTPException(status_code=503, detail="Qdrant клиент не инициализирован")
        
        try:
            document_id_int = int(document_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Неверный формат ID документа")
        
        # Удаление из Qdrant
        qdrant_client.delete(
            collection_name="documents",
            points_selector=models.PointIdsList(
                points=[document_id_int]
            )
        )
        
        logger.info(f"Документ {document_id} удален")
        
        return {"message": f"Документ {document_id} успешно удален"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка удаления документа: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка удаления документа: {str(e)}")

@app.get("/documents", response_model=Dict[str, Any])
async def list_documents(
    query: Optional[str] = None,
    category: Optional[str] = None,
    tag: Optional[str] = None,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    limit: int = 10,
    offset: int = 0
):
    """Получение списка документов с фильтрацией и сортировкой"""
    try:
        if not db_pool:
            logger.warning("PostgreSQL pool не инициализирован, возвращаем пустой список документов.")
            return {"documents": [], "total": 0, "limit": limit, "offset": offset, "error": "Database not initialized"}

        async with db_pool.acquire() as conn:
            sql_query = "SELECT filename, content, metadata, categories, tags, version, created_at, last_modified_at FROM documents WHERE 1=1"
            params = []
            param_idx = 1

            if query:
                sql_query += f" AND (filename ILIKE ${param_idx} OR content ILIKE ${param_idx})"
                params.append(f"%{query}%")
                param_idx += 1
            if category:
                sql_query += f" AND categories @> ARRAY[${param_idx}]::text[]"
                params.append(category)
                param_idx += 1
            if tag:
                sql_query += f" AND tags @> ARRAY[${param_idx}]::text[]"
                params.append(tag)
                param_idx += 1

            # Подсчет общего количества документов
            count_query = f"SELECT COUNT(*) FROM ({sql_query}) AS subquery"
            total_count = await conn.fetchval(count_query, *params)

            # Добавление сортировки и пагинации
            order_by_clause = ""
            if sort_by in ["filename", "created_at", "last_modified_at"]:
                order_by_clause = f" ORDER BY {sort_by}"
                if sort_order.lower() == "desc":
                    order_by_clause += " DESC"
                else:
                    order_by_clause += " ASC"
            else:
                order_by_clause = " ORDER BY created_at DESC" # По умолчанию

            sql_query += f"{order_by_clause} LIMIT ${param_idx} OFFSET ${param_idx + 1}"
            params.append(limit)
            params.append(offset)

            records = await conn.fetch(sql_query, *params)

            documents = []
            for record in records:
                doc_id = abs(hash(record["filename"] + record["content"][:100])) # Генерируем ID как в Qdrant
                documents.append(DocumentInfo(
                    id=str(doc_id),
                    title=record["filename"],
                    content=record["content"],
                    metadata=record["metadata"],
                    categories=record["categories"],
                    tags=record["tags"],
                    version=record["version"],
                    created_at=record["created_at"].isoformat() if record["created_at"] else None,
                    last_modified_at=record["last_modified_at"].isoformat() if record["last_modified_at"] else None
                ).dict())

            return {
                "documents": documents,
                "total": total_count,
                "limit": limit,
                "offset": offset
            }

    except Exception as e:
        logger.error(f"Ошибка получения списка документов: {e}")
        raise HTTPException(status_code=500, detail=f"Ошибка получения списка документов: {str(e)}")

# Служебные функции
async def process_document_async(file_path: str, filename: str, metadata: Optional[str], categories: Optional[str], tags: Optional[str]):
    """Асинхронная обработка документа"""
    try:
        logger.info(f"Начало обработки документа: {filename}")
          # Чтение файла
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            
        # Создание эмбеддинга
        if embedding_model and qdrant_client:
            logger.info(f"Создание эмбеддинга для документа {filename}")
            embedding = embedding_model.encode([content])[0].tolist()
              # Сохранение в Qdrant
            doc_id = abs(hash(filename + content[:100]))  # Используем abs() для положительного числа
            
            # Парсинг категорий и тегов
            parsed_categories = [c.strip() for c in categories.split(',')] if categories else []
            parsed_tags = [t.strip() for t in tags.split(',')] if tags else []

            # Сохранение в Qdrant
            doc_id = abs(hash(filename + content[:100]))  # Используем abs() для положительного числа
            current_time = datetime.now().isoformat()
            
            qdrant_client.upsert(
                collection_name="documents",
                points=[
                    models.PointStruct(
                        id=doc_id,
                        vector=embedding,
                        payload={
                            "title": filename,
                            "content": content,
                            "metadata": {"filename": filename, "upload_date": current_time, **(json.loads(metadata) if metadata else {})},
                            "categories": parsed_categories,
                            "tags": parsed_tags,
                            "version": "1.0", # Начальная версия
                            "created_at": current_time,
                            "last_modified_at": current_time,
                            "size": len(content)
                        }
                    )
                ]
            )
            
            logger.info(f"Документ {filename} сохранен в Qdrant с ID: {doc_id}")
        
        # Сохранение метаданных в PostgreSQL
        if db_pool:
            async with db_pool.acquire() as conn:
                await conn.execute("""
                    INSERT INTO documents (filename, content, metadata, categories, tags, version, created_at, last_modified_at)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                    ON CONFLICT (filename) DO UPDATE SET
                        content = EXCLUDED.content,
                        metadata = EXCLUDED.metadata,
                        categories = EXCLUDED.categories,
                        tags = EXCLUDED.tags,
                        version = EXCLUDED.version,
                        last_modified_at = EXCLUDED.last_modified_at,
                        updated_at = NOW()
                """, 
                filename, 
                content, 
                json.dumps(json.loads(metadata) if metadata else {}), 
                json.dumps(parsed_categories), 
                json.dumps(parsed_tags), 
                "1.0", # Начальная версия
                datetime.now(),
                datetime.now()
                )
                
            logger.info(f"Метаданные документа {filename} сохранены в PostgreSQL")
        
        # Очистка временного файла
        os.unlink(file_path)
        
        logger.info(f"Обработка документа {filename} завершена успешно")
        
    except Exception as e:
        logger.error(f"Ошибка асинхронной обработки: {e}")
        if os.path.exists(file_path):
            os.unlink(file_path)

# Дополнительные endpoints для интеграции с N8N
@app.get("/status")
async def get_status():
    """Статус сервиса для мониторинга"""
    return {
        "service": "document-processor",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "version": "1.2.0"
    }

@app.get("/metrics")
async def get_metrics():
    """Метрики сервиса"""
    return {
        "documents_processed": 0,  # placeholder
        "embeddings_created": 0,   # placeholder
        "searches_performed": 0,   # placeholder
        "uptime": "0h 0m 0s"      # placeholder
    }

if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        log_level="info"
    )
