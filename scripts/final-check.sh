#!/bin/bash

# 🚀 Итоговая проверка успешного развертывания

echo "🎯 ИТОГОВАЯ ПРОВЕРКА N8N AI STARTER KIT"
echo "======================================"

# Быстрая проверка всех ключевых компонентов
echo "📋 1. Быстрая проверка ключевых компонентов:"

# Проверка контейнеров
running_containers=$(docker compose -f compose/test-minimal.yml ps --format "table {{.Service}}" | grep -v SERVICE | wc -l)
echo "✅ Запущено контейнеров: $running_containers"

# Проверка N8N
echo -n "✅ N8N доступность: "
if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    echo "РАБОТАЕТ"
else
    echo "НЕ ОТВЕЧАЕТ"
fi

# Проверка базы данных
echo -n "✅ PostgreSQL: "
if docker exec compose-postgres-test-1 pg_isready -U postgres >/dev/null 2>&1; then
    echo "ПОДКЛЮЧЕНИЕ OK"
else
    echo "ПРОБЛЕМЫ С ПОДКЛЮЧЕНИЕМ"
fi

# Проверка создания пользователя N8N в БД
echo -n "✅ Пользователь N8N в БД: "
if docker exec compose-postgres-test-1 psql -U postgres -c "\du" | grep -q n8n; then
    echo "СОЗДАН"
else
    echo "НЕ НАЙДЕН"
fi

# Проверка создания базы данных N8N
echo -n "✅ База данных N8N: "
if docker exec compose-postgres-test-1 psql -U postgres -c "\l" | grep -q " n8n "; then
    echo "СОЗДАНА"
else
    echo "НЕ НАЙДЕНА"
fi

echo
echo "📋 2. Проверка доступности Web интерфейсов:"

local_ip=$(hostname -I | awk '{print $1}')

# Проверка N8N интерфейса
echo "🌐 N8N Web Interface:"
echo "   👉 http://localhost:5678"
echo "   👉 http://$local_ip:5678"

# Проверка Qdrant если запущен
if docker compose -f compose/test-minimal.yml ps | grep -q qdrant-test; then
    echo "🗄️  Qdrant Dashboard:"
    echo "   👉 http://localhost:6333/dashboard"
    echo "   👉 http://$local_ip:6333/dashboard"
fi

echo
echo "📋 3. Тест создания простого workflow:"
echo "1. Откройте http://localhost:5678 в браузере"
echo "2. Нажмите 'Add first step' или '+'"
echo "3. Выберите 'Manual Trigger'"
echo "4. Добавьте ещё один узел: 'Set'"
echo "5. Нажмите 'Test workflow' для проверки"

echo
echo "📋 4. Информация о системе:"
echo "Операционная система: $(lsb_release -d | cut -f2)"
echo "Docker версия: $(docker --version)"
echo "Docker Compose версия: $(docker compose version --short)"
echo "Доступная память: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Свободное место: $(df -h / | awk 'NR==2 {print $4}')"

echo
echo "📋 5. Логи для отладки (если нужно):"
echo "Все логи: docker compose -f compose/test-minimal.yml logs -f"
echo "Только N8N: docker compose -f compose/test-minimal.yml logs -f n8n-test"
echo "Только PostgreSQL: docker compose -f compose/test-minimal.yml logs -f postgres-test"

echo
echo "📋 6. Управление тестовой средой:"
echo "Остановка: docker compose -f compose/test-minimal.yml down"
echo "Перезапуск: docker compose -f compose/test-minimal.yml restart"
echo "Статус: docker compose -f compose/test-minimal.yml ps"

echo
echo "🎉 РЕЗУЛЬТАТ:"
echo "==============="
if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    echo "✅ N8N AI Starter Kit успешно развёрнут и готов к использованию!"
    echo "✅ Тестовая среда работает корректно"
    echo "✅ Можно переходить к созданию workflows"
    echo
    echo "🚀 СЛЕДУЮЩИЕ ШАГИ:"
    echo "1. Откройте N8N в браузере: http://localhost:5678"
    echo "2. Создайте свой первый workflow"
    echo "3. При необходимости запустите полную версию: docker compose --profile cpu up -d"
else
    echo "❌ Возникли проблемы с доступностью N8N"
    echo "🔧 Попробуйте перезапустить: docker compose -f compose/test-minimal.yml restart n8n-test"
fi
