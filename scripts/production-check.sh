#!/bin/bash

# 🚀 Проверка Production-окружения N8N AI Starter Kit

echo "🎯 ПРОВЕРКА PRODUCTION-ОКРУЖЕНИЯ N8N AI STARTER KIT"
echo "=================================================="

# Быстрая проверка всех ключевых компонентов
echo "📋 1. Быстрая проверка ключевых компонентов:"

# Проверка контейнеров (production профиль)
running_containers=$(docker compose ps --format "table {{.Service}}" | grep -v SERVICE | wc -l)
echo "✅ Запущено контейнеров (production): $running_containers"

# Проверка N8N
echo -n "✅ N8N доступность: "
if curl -s -f http://localhost:5678 >/dev/null 2>&1; then
    echo "РАБОТАЕТ"
else
    echo "НЕ ОТВЕЧАЕТ"
fi

# Проверка базы данных (production имена контейнеров)
echo -n "✅ PostgreSQL: "
if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then
    echo "ПОДКЛЮЧЕНИЕ OK"
else
    echo "ПРОБЛЕМЫ С ПОДКЛЮЧЕНИЕМ"
fi

# Проверка создания пользователя N8N в БД
echo -n "✅ Пользователь N8N в БД: "
if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "\du" | grep -q n8n; then
    echo "СОЗДАН"
else
    echo "НЕ НАЙДЕН"
fi

# Проверка создания базы данных N8N
echo -n "✅ База данных N8N: "
if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "\l" | grep -q " n8n "; then
    echo "СОЗДАНА"
else
    echo "НЕ НАЙДЕНА"
fi

# Проверка Ollama
echo -n "✅ Ollama API: "
if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "ДОСТУПЕН"
    # Проверяем установленные модели
    model_count=$(curl -s http://localhost:11434/api/tags | jq -r '.models | length' 2>/dev/null || echo "0")
    echo "   📦 Установлено моделей: $model_count"
else
    echo "НЕ ОТВЕЧАЕТ"
fi

# Проверка Qdrant
echo -n "✅ Qdrant API: "
if curl -s -f http://localhost:6333/health >/dev/null 2>&1; then
    echo "РАБОТАЕТ"
else
    echo "НЕ ОТВЕЧАЕТ"
fi

# Проверка Traefik (если используется)
echo -n "✅ Traefik Dashboard: "
if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
    echo "ДОСТУПЕН"
else
    echo "НЕ НАСТРОЕН/НЕ ДОСТУПЕН"
fi

# Проверка Graphiti (если включен)
echo -n "✅ Graphiti API: "
if docker compose ps | grep -q graphiti && curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
    echo "РАБОТАЕТ"
else
    echo "НЕ ЗАПУЩЕН/НЕ ОТВЕЧАЕТ"
fi

echo
echo "📋 2. Проверка доступности Web интерфейсов:"

local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || ipconfig | findstr "IPv4" | head -1 | awk '{print $NF}')

# Проверка N8N интерфейса
echo "🌐 N8N Web Interface:"
echo "   👉 http://localhost:5678"
echo "   👉 http://$local_ip:5678"

# Проверка Qdrant Dashboard
if docker compose ps | grep -q qdrant; then
    echo "🗄️  Qdrant Dashboard:"
    echo "   👉 http://localhost:6333/dashboard"
    echo "   👉 http://$local_ip:6333/dashboard"
fi

# Проверка Traefik Dashboard
if docker compose ps | grep -q traefik; then
    echo "🔀 Traefik Dashboard:"
    echo "   👉 http://localhost:8080"
    echo "   👉 http://$local_ip:8080"
fi

echo
echo "📋 3. Production-специфичные проверки:"

# Проверка ресурсов
echo "💾 Использование ресурсов:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10

echo
echo "🔧 Здоровье контейнеров:"
docker compose ps --format "table {{.Service}}\t{{.State}}\t{{.Status}}"

echo
echo "📋 4. Информация о системе:"
if command -v lsb_release >/dev/null 2>&1; then
    echo "Операционная система: $(lsb_release -d | cut -f2)"
else
    echo "Операционная система: Windows $(systeminfo | findstr "OS Name" | cut -d: -f2 | sed 's/^ *//')"
fi
echo "Docker версия: $(docker --version)"
echo "Docker Compose версия: $(docker compose version --short)"
if command -v free >/dev/null 2>&1; then
    echo "Доступная память: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Свободное место: $(df -h / | awk 'NR==2 {print $4}')"
else
    echo "Доступная память: $(wmic computersystem get TotalPhysicalMemory /value | grep "=" | cut -d= -f2 | awk '{printf "%.1f GB", $1/1024/1024/1024}')"
fi

echo
echo "📋 5. Логи для отладки (если нужно):"
echo "Все логи: docker compose logs -f"
echo "Только N8N: docker compose logs -f n8n"
echo "Только PostgreSQL: docker compose logs -f postgres"
echo "Только Ollama: docker compose logs -f ollama"
echo "Только Qdrant: docker compose logs -f qdrant"

echo
echo "📋 6. Управление production-средой:"
echo "Остановка: docker compose --profile cpu down"
echo "Перезапуск: docker compose --profile cpu restart"
echo "Статус: docker compose --profile cpu ps"
echo "Обновление: docker compose --profile cpu pull && docker compose --profile cpu up -d"

echo
echo "🎉 РЕЗУЛЬТАТ PRODUCTION-ПРОВЕРКИ:"
echo "================================="

success_count=0
total_checks=6

# Подсчет успешных проверок
if curl -s -f http://localhost:5678 >/dev/null 2>&1; then success_count=$((success_count + 1)); fi
if docker exec n8n-ai-starter-kit-postgres-1 pg_isready -U postgres >/dev/null 2>&1; then success_count=$((success_count + 1)); fi
if curl -s -f http://localhost:11434/api/tags >/dev/null 2>&1; then success_count=$((success_count + 1)); fi
if curl -s -f http://localhost:6333/health >/dev/null 2>&1; then success_count=$((success_count + 1)); fi
if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "\du" | grep -q n8n; then success_count=$((success_count + 1)); fi
if docker exec n8n-ai-starter-kit-postgres-1 psql -U postgres -c "\l" | grep -q " n8n "; then success_count=$((success_count + 1)); fi

echo "📊 Успешных проверок: $success_count/$total_checks"

if [ $success_count -eq $total_checks ]; then
    echo "✅ Production-окружение N8N AI Starter Kit полностью работоспособно!"
    echo "✅ Все основные сервисы запущены и отвечают"
    echo "✅ База данных настроена корректно"
    echo "✅ AI-сервисы (Ollama, Qdrant) функционируют"
    echo
    echo "🚀 PRODUCTION ГОТОВ К ИСПОЛЬЗОВАНИЮ!"
    echo "1. Откройте N8N в браузере: http://localhost:5678"
    echo "2. Начните создавать AI-powered workflows"
    echo "3. Используйте Ollama для локальных LLM"
    echo "4. Используйте Qdrant для векторного поиска"
elif [ $success_count -gt $((total_checks / 2)) ]; then
    echo "⚠️  Production-окружение частично работоспособно ($success_count/$total_checks)"
    echo "🔧 Рекомендуется проверить логи неработающих сервисов"
    echo "🔧 Команда для диагностики: docker compose logs -f"
else
    echo "❌ Критические проблемы в production-окружении ($success_count/$total_checks)"
    echo "🚨 Необходимо срочное исправление"
    echo "🔧 Попробуйте перезапустить: docker compose --profile cpu restart"
    echo "🔧 Или полный перезапуск: docker compose --profile cpu down && docker compose --profile cpu up -d"
fi
