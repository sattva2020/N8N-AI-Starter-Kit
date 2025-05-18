#!/bin/bash
# filepath: scripts/backup.sh

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/n8n_backup_${TIMESTAMP}.tar.gz"
LOG_DIR="./logs"
MAX_BACKUPS=7  # Хранить максимум 7 последних бэкапов

# Создание необходимых директорий
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

echo "==================================="
echo "  N8N AI Starter Kit - Бэкап данных"
echo "==================================="
echo "Дата и время: $(date)"

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_DIR}/backup.log"
}

log "Создание бэкапа в $BACKUP_FILE..."

# Экспорт Postgres данных
log "Экспорт данных PostgreSQL..."
docker compose exec -T postgres pg_dump -U root -d n8n > "${BACKUP_DIR}/n8n_db_${TIMESTAMP}.sql" 2>> "${LOG_DIR}/backup_error.log"
if [ $? -ne 0 ]; then
    log "ОШИБКА: Не удалось экспортировать данные PostgreSQL"
else
    log "Данные PostgreSQL успешно экспортированы"
fi

# Экспорт Supabase данных (если используется)
if docker compose ps | grep -q supabase-db; then
    log "Экспорт данных Supabase..."
    docker compose exec -T db pg_dump -U postgres -d postgres > "${BACKUP_DIR}/supabase_db_${TIMESTAMP}.sql" 2>> "${LOG_DIR}/backup_error.log"
    if [ $? -ne 0 ]; then
        log "ОШИБКА: Не удалось экспортировать данные Supabase"
    else
        log "Данные Supabase успешно экспортированы"
    fi
fi

# Архивация данных n8n
log "Архивация данных..."
tar -czf "$BACKUP_FILE" \
    "${BACKUP_DIR}/n8n_db_${TIMESTAMP}.sql" \
    "${BACKUP_DIR}/supabase_db_${TIMESTAMP}.sql" \
    .env \
    ./volumes \
    --exclude="./volumes/postgres_data" \
    --exclude="./volumes/supabase_db" \
    --exclude="./volumes/neo4j_data" \
    --exclude="./backups" \
    2>> "${LOG_DIR}/backup_error.log"

# Очистка временных файлов
rm "${BACKUP_DIR}/n8n_db_${TIMESTAMP}.sql"
rm "${BACKUP_DIR}/supabase_db_${TIMESTAMP}.sql" 2>/dev/null

# Очистка старых резервных копий
log "Удаление старых резервных копий..."
ls -tp ${BACKUP_DIR}/n8n_backup_*.tar.gz | grep -v '/$' | tail -n +$((MAX_BACKUPS+1)) | xargs -I {} rm -- {} 2>/dev/null
if [ $? -eq 0 ]; then
    log "Старые резервные копии успешно удалены (оставлено максимум ${MAX_BACKUPS})"
fi

backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
log "Бэкап успешно создан в: $BACKUP_FILE (размер: $backup_size)"
log "Завершено. Полный журнал доступен в: ${LOG_DIR}/backup.log"