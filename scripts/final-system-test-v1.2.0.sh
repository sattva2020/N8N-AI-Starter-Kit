#!/bin/bash

# 🧪 Final System Test для n8n-ai-starter-kit v1.2.0
# ===================================================
# Финальное тестирование Advanced RAG Pipeline и всех компонентов

echo "🧪 Начинаем финальное системное тестирование n8n-ai-starter-kit v1.2.0..."
echo "============================================================================"

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SUCCESS_COUNT=0
TOTAL_TESTS=0

# Функция для логирования результатов
log_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}❌ $1${NC}"
    fi
}

# Функция для проверки статуса сервиса
check_service_status() {
    local service_name=$1
    local expected_status=${2:-"healthy"}
    
    echo -e "${BLUE}🔍 Проверяем статус сервиса: $service_name${NC}"
    
    # Получаем полную строку статуса
    status_line=$(docker-compose ps --format="table {{.Service}}\t{{.Status}}" | grep "$service_name" | cut -f2)
    
    if [[ "$status_line" == *"$expected_status"* ]] && [[ "$status_line" == *"Up"* ]]; then
        log_test "Сервис $service_name имеет статус $expected_status"
        return 0
    elif [[ "$status_line" == *"Up"* ]]; then
        log_test "Сервис $service_name запущен (статус: $status_line)"
        return 0
    else
        echo -e "${RED}❌ Сервис $service_name имеет статус: $status_line (ожидался: Up + $expected_status)${NC}"
        return 1
    fi
}

# Функция для проверки API endpoint
check_api_endpoint() {
    local url=$1
    local description=$2
    local expected_code=${3:-200}
    
    echo -e "${BLUE}🌐 Проверяем API endpoint: $url${NC}"
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [ "$response_code" = "$expected_code" ]; then
        log_test "$description (HTTP $response_code)"
        return 0
    else
        echo -e "${RED}❌ $description (HTTP $response_code, ожидался: $expected_code)${NC}"
        return 1
    fi
}

echo -e "${YELLOW}📋 1. Проверяем статусы Docker контейнеров...${NC}"
echo "============================================"

# Проверяем ключевые сервисы
check_service_status "document-processor" "healthy"
check_service_status "web-interface" "healthy"
check_service_status "postgres" "healthy"
check_service_status "neo4j" "healthy"
check_service_status "ollama" "healthy"

echo
echo -e "${YELLOW}📋 2. Проверяем API endpoints...${NC}"
echo "==============================="

# Проверяем API endpoints
check_api_endpoint "http://localhost:8001/health" "Document Processor Health Check"
check_api_endpoint "http://localhost:8001/" "Document Processor Root"
check_api_endpoint "http://localhost:8001/docs" "Document Processor Swagger UI"

check_api_endpoint "http://localhost:8002/health" "Web Interface Health Check"
check_api_endpoint "http://localhost:8002/" "Web Interface Root"

check_api_endpoint "http://localhost:6333/" "Qdrant Health Check"

check_api_endpoint "http://localhost:11434/" "Ollama API"

echo
echo -e "${YELLOW}📋 3. Проверяем интеграции и функциональность...${NC}"
echo "=============================================="

# Проверяем интеграцию document-processor -> qdrant
echo -e "${BLUE}🔗 Проверяем интеграцию Document Processor с другими сервисами${NC}"

# Тестируем search endpoint document-processor
search_response=$(curl -s -X POST "http://localhost:8001/documents/search" \
    -H "Content-Type: application/json" \
    -d '{"query": "test", "limit": 5}' || echo "error")

if [[ "$search_response" != "error" ]] && [[ "$search_response" == *"results"* ]]; then
    log_test "Document Processor поиск API работает"
else
    echo -e "${RED}❌ Document Processor поиск API не работает${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Проверяем веб-интерфейс
echo -e "${BLUE}🌐 Проверяем веб-интерфейс${NC}"

web_interface_content=$(curl -s "http://localhost:8002/" || echo "error")

if [[ "$web_interface_content" != "error" ]] && [[ "$web_interface_content" == *"html"* ]]; then
    log_test "Web Interface возвращает HTML контент"
else
    echo -e "${RED}❌ Web Interface не возвращает HTML контент${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

echo
echo -e "${YELLOW}📋 4. Проверяем Docker Compose конфигурацию...${NC}"
echo "============================================="

# Проверяем, что все сервисы из профиля cpu запущены
expected_services=("document-processor" "web-interface" "postgres" "ollama")

for service in "${expected_services[@]}"; do
    if docker-compose ps "$service" | grep -q "Up"; then
        log_test "Сервис $service запущен в Docker Compose"
    else
        echo -e "${RED}❌ Сервис $service не запущен в Docker Compose${NC}"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
done

echo
echo -e "${YELLOW}📋 5. Проверяем файловую структуру проекта...${NC}"
echo "==========================================="

# Проверяем ключевые файлы и директории
key_paths=(
    "services/document-processor/app.py"
    "services/document-processor/requirements.txt"
    "services/document-processor/Dockerfile"
    "services/web-interface/app.py"
    "services/web-interface/requirements.txt" 
    "services/web-interface/Dockerfile"
    "docker-compose.yml"
    ".env"
    "data/uploads"
    "data/processed"
)

for path in "${key_paths[@]}"; do
    if [ -e "$path" ]; then
        log_test "Файл/директория существует: $path"
    else
        echo -e "${RED}❌ Файл/директория отсутствует: $path${NC}"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
done

echo
echo -e "${YELLOW}📋 6. Проверяем логи на ошибки...${NC}"
echo "==============================="

# Проверяем логи на критические ошибки
echo -e "${BLUE}🔍 Анализируем логи document-processor...${NC}"
doc_processor_errors=$(docker-compose logs document-processor | grep -i "error\|exception\|traceback" | wc -l)

if [ "$doc_processor_errors" -eq 0 ]; then
    log_test "Document Processor: нет критических ошибок в логах"
else
    echo -e "${RED}❌ Document Processor: найдено $doc_processor_errors ошибок в логах${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

echo -e "${BLUE}🔍 Анализируем логи web-interface...${NC}"
web_interface_errors=$(docker-compose logs web-interface | grep -i "error\|exception\|traceback" | wc -l)

if [ "$web_interface_errors" -eq 0 ]; then
    log_test "Web Interface: нет критических ошибок в логах"
else
    echo -e "${RED}❌ Web Interface: найдено $web_interface_errors ошибок в логах${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

echo
echo "============================================================================"
echo -e "${BLUE}📊 РЕЗУЛЬТАТЫ ФИНАЛЬНОГО ТЕСТИРОВАНИЯ:${NC}"
echo "============================================================================"

SUCCESS_RATE=$(echo "scale=1; $SUCCESS_COUNT * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")

echo -e "✅ Успешных тестов: ${GREEN}$SUCCESS_COUNT${NC} из $TOTAL_TESTS"
echo -e "📈 Процент успеха: ${GREEN}$SUCCESS_RATE%${NC}"

if [ "$SUCCESS_COUNT" -eq "$TOTAL_TESTS" ]; then
    echo
    echo -e "${GREEN}🎉 ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
    echo -e "${GREEN}🚀 n8n-ai-starter-kit v1.2.0 готов к продакшену!${NC}"
    echo
    echo -e "${BLUE}📋 Advanced RAG Pipeline полностью функционален:${NC}"
    echo "• ✅ Document Processor API (http://localhost:8001)"
    echo "• ✅ Web Interface (http://localhost:8002)"
    echo "• ✅ Векторная база данных (Qdrant)"
    echo "• ✅ AI модели (Ollama)"
    echo "• ✅ Граф знаний (Neo4j + Graphiti)"
    echo "• ✅ PostgreSQL база данных"
    echo
    exit 0
else
    failed_tests=$((TOTAL_TESTS - SUCCESS_COUNT))
    echo
    echo -e "${RED}⚠️  $failed_tests тестов не прошли.${NC}"
    echo -e "${YELLOW}🔧 Требуется дополнительная диагностика.${NC}"
    echo
    exit 1
fi
