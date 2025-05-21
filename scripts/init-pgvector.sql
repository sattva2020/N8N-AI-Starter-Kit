-- Установка необходимых расширений
CREATE EXTENSION IF NOT EXISTS vector;

-- Настройка индексирования для векторных операций
ALTER SYSTEM SET maintenance_work_mem = '128MB';
ALTER SYSTEM SET max_parallel_maintenance_workers = '2';

-- Оптимизация для векторных запросов
ALTER SYSTEM SET effective_cache_size = '512MB';
ALTER SYSTEM SET random_page_cost = '1.1';

-- Логирование
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
