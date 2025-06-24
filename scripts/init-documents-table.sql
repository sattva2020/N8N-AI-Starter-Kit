-- SQL скрипт для инициализации таблицы документов
-- ===============================================

-- Создание расширения pgvector если не существует
CREATE EXTENSION IF NOT EXISTS vector;

-- Создание таблицы для метаданных документов
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) UNIQUE NOT NULL,
    title VARCHAR(500),
    content TEXT,
    metadata JSONB DEFAULT '{}',
    file_size INTEGER,
    content_type VARCHAR(100),
    
    -- Векторное представление документа (для pgvector)
    embedding vector(384),
    
    -- Временные метки
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- Создание индексов для поиска
CREATE INDEX IF NOT EXISTS idx_documents_filename ON documents(filename);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_metadata ON documents USING GIN(metadata);

-- Создание индекса для векторного поиска (HNSW для быстрого поиска)
CREATE INDEX IF NOT EXISTS idx_documents_embedding ON documents 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- Создание таблицы для логирования поисковых запросов
CREATE TABLE IF NOT EXISTS search_logs (
    id SERIAL PRIMARY KEY,
    query TEXT NOT NULL,
    results_count INTEGER DEFAULT 0,
    execution_time_ms INTEGER,
    user_id VARCHAR(100),
    session_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Создание индексов для аналитики
CREATE INDEX IF NOT EXISTS idx_search_logs_created_at ON search_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_search_logs_user_id ON search_logs(user_id);

-- Создание функции для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Создание триггера для автоматического обновления updated_at
DROP TRIGGER IF EXISTS update_documents_updated_at ON documents;
CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Вставка примера документа для тестирования (если таблица пустая)
INSERT INTO documents (filename, title, content, metadata)
SELECT 
    'welcome.md',
    'Добро пожаловать в Document Processor',
    'Это тестовый документ для проверки функциональности системы обработки документов. Система поддерживает загрузку, индексацию и семантический поиск документов.',
    '{"type": "test", "language": "ru", "category": "welcome"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM documents WHERE filename = 'welcome.md');

-- Создание представления для аналитики
CREATE OR REPLACE VIEW documents_analytics AS
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as documents_uploaded,
    AVG(file_size) as avg_file_size,
    COUNT(CASE WHEN processed_at IS NOT NULL THEN 1 END) as processed_count
FROM documents
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- Создание представления для поисковой аналитики
CREATE OR REPLACE VIEW search_analytics AS
SELECT 
    DATE_TRUNC('hour', created_at) as hour,
    COUNT(*) as search_count,
    AVG(execution_time_ms) as avg_execution_time_ms,
    AVG(results_count) as avg_results_count
FROM search_logs
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;

-- Вывод статистики
SELECT 'Таблицы инициализированы успешно' as status;
SELECT COUNT(*) as documents_count FROM documents;
SELECT COUNT(*) as search_logs_count FROM search_logs;
