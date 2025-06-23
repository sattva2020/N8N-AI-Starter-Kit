#!/bin/bash

# 🔍 Проверка работоспособности N8N

echo "🔍 Тестирование функциональности N8N"
echo "=================================="

local_ip=$(hostname -I | awk '{print $1}')

echo "📋 1. Проверка основных endpoint'ов N8N:"

# Проверка главной страницы
echo -n "Главная страница: "
if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    echo "✅ Доступна"
else
    echo "❌ Недоступна"
fi

# Проверка health endpoint
echo -n "Health check: "
if curl -s -f http://localhost:5678/healthz >/dev/null 2>&1; then
    echo "✅ Прошел"
else
    echo "❌ Не прошел"
fi

# Проверка API
echo -n "API (/rest/login): "
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/rest/login)
if [[ "$response" =~ ^(200|401|403)$ ]]; then
    echo "✅ Отвечает (код: $response)"
else
    echo "❌ Не отвечает (код: $response)"
fi

echo
echo "📋 2. Проверка подключения к базе данных:"
if docker exec compose-n8n-test-1 node -e "
const { DataSource } = require('typeorm');
const config = {
    type: 'postgres',
    host: 'postgres-test',
    port: 5432,
    username: 'n8n',
    password: 'n8npassword123',
    database: 'n8n'
};
const dataSource = new DataSource(config);
dataSource.initialize().then(() => {
    console.log('✅ Подключение к БД успешно');
    process.exit(0);
}).catch(err => {
    console.log('❌ Ошибка подключения к БД:', err.message);
    process.exit(1);
});
" 2>/dev/null; then
    echo "База данных доступна для N8N"
else
    echo "Проблемы с подключением к базе данных"
fi

echo
echo "📋 3. Информация о версии N8N:"
docker exec compose-n8n-test-1 n8n --version 2>/dev/null || echo "Не удалось получить версию"

echo
echo "📋 4. Проверка файловой системы N8N:"
echo "Содержимое директории N8N:"
docker exec compose-n8n-test-1 ls -la /home/node/.n8n/ 2>/dev/null || echo "Директория пуста или недоступна"

echo
echo "📋 5. Рекомендации по тестированию:"
echo "1. Откройте в браузере: http://localhost:5678"
echo "2. Или через сеть: http://$local_ip:5678"
echo "3. Создайте тестовый workflow для проверки функциональности"
echo "4. Проверьте подключение к PostgreSQL из N8N интерфейса"

if docker compose -f compose/test-minimal.yml ps | grep -q qdrant-test; then
    echo "5. Проверьте Qdrant dashboard: http://localhost:6333/dashboard"
fi

echo
echo "📋 6. Если возникают проблемы:"
echo "Перезапуск N8N:"
echo "  docker compose -f compose/test-minimal.yml restart n8n-test"
echo
echo "Полные логи:"
echo "  docker compose -f compose/test-minimal.yml logs -f n8n-test"
echo
echo "Подключение к контейнеру:"
echo "  docker exec -it compose-n8n-test-1 /bin/bash"
