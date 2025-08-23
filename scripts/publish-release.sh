#!/bin/bash

# 🚀 N8N AI Starter Kit - Скрипт Публикации v1.1.4
# Автоматизированная публикация релиза

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Версия для релиза
VERSION="v1.1.4"
RELEASE_TITLE="🚀 N8N AI Starter Kit v1.1.4 - Enterprise AI Automation Platform"

echo -e "${BLUE}🚀 N8N AI Starter Kit - Публикация Релиза ${VERSION}${NC}"
echo "=================================================="

# Этап 1: Проверка готовности
echo -e "\n${YELLOW}📋 ЭТАП 1: Проверка готовности${NC}"

echo "🔍 Проверяем статус Git..."
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}❌ Есть незакоммиченные изменения!${NC}"
    git status --short
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "🔍 Проверяем временные файлы..."
temp_files=$(find . -maxdepth 1 -name "*SUCCESS*.md" -o -name "*FINAL*.md" -o -name "*REPORT*.md" -o -name "*TEST*.md" | wc -l)
if [ $temp_files -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Найдены временные файлы:${NC}"
    find . -maxdepth 1 -name "*SUCCESS*.md" -o -name "*FINAL*.md" -o -name "*REPORT*.md" -o -name "*TEST*.md"
    read -p "Удалить их? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        find . -maxdepth 1 \( -name "*SUCCESS*.md" -o -name "*FINAL*.md" -o -name "*REPORT*.md" -o -name "*TEST*.md" \) -delete
        echo -e "${GREEN}✅ Временные файлы удалены${NC}"
    fi
fi

# Этап 2: Финальный коммит
echo -e "\n${YELLOW}📦 ЭТАП 2: Создание финального коммита${NC}"

read -p "Создать финальный коммит? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    git add .
    git commit -m "🚀 RELEASE ${VERSION}: Final cleanup and preparation for publication" || echo "Нет изменений для коммита"
    echo -e "${GREEN}✅ Финальный коммит создан${NC}"
fi

# Этап 3: Создание тега
echo -e "\n${YELLOW}🏷️  ЭТАП 3: Создание тега релиза${NC}"

# Проверяем существует ли тег
if git rev-parse $VERSION >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Тег $VERSION уже существует${NC}"
    read -p "Пересоздать тег? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git tag -d $VERSION
        git push --delete origin $VERSION 2>/dev/null || true
    else
        echo -e "${BLUE}ℹ️  Используем существующий тег${NC}"
    fi
fi

if ! git rev-parse $VERSION >/dev/null 2>&1; then
    echo "📝 Создаем аннотированный тег..."
    git tag -a $VERSION -m "Release ${VERSION}: Advanced N8N Workflows & Production Security

🚀 Major Features:
- 6 Advanced N8N Workflows для полной автоматизации
- SSL Production Setup с Let's Encrypt
- Auto-Import система для workflows
- Production Security с enterprise-grade headers
- Comprehensive monitoring & analytics

✨ New Components:
- Document Processing Pipeline
- RAG Query Automation  
- Batch Processing (до 50 файлов)
- Error Handling & Notifications
- System Monitoring
- Email Integration

🔗 API Enhancements:
- 5 новых webhook endpoints
- RESTful API design
- Automated error handling
- Rate limiting готовность

📚 Complete Documentation:
- Production deployment guides
- SSL setup instructions
- API reference with examples
- Troubleshooting guides"

    echo -e "${GREEN}✅ Тег $VERSION создан${NC}"
fi

# Этап 4: Push изменений
echo -e "\n${YELLOW}⬆️  ЭТАП 4: Публикация в репозиторий${NC}"

read -p "Push изменения в origin? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo "📤 Push основной ветки..."
    git push origin $(git branch --show-current)
    
    echo "📤 Push тега..."
    git push origin $VERSION
    
    echo -e "${GREEN}✅ Изменения опубликованы в репозиторий${NC}"
fi

# Этап 5: Информация для GitHub Release
echo -e "\n${YELLOW}🌐 ЭТАП 5: Создание GitHub Release${NC}"

echo -e "${BLUE}"
echo "=================================================="
echo "         СЛЕДУЮЩИЕ ШАГИ НА GITHUB"
echo "=================================================="
echo -e "${NC}"

echo "1. Перейдите на: https://github.com/sattva2020/N8N-AI-Starter-Kit/releases"
echo "2. Нажмите 'Create a new release'"
echo "3. Выберите тег: $VERSION"
echo "4. Заголовок релиза: $RELEASE_TITLE"
echo ""
echo "5. Используйте следующий контент для Release Notes:"
echo -e "${GREEN}============ RELEASE NOTES ============${NC}"

cat << 'EOF'
🚀 **ENTERPRISE-READY AI AUTOMATION PLATFORM**

Это крупное обновление превращает базовый стартовый набор в enterprise-ready AI систему с полной автоматизацией, мониторингом и production-grade безопасностью.

## ✨ КЛЮЧЕВЫЕ НОВОВВЕДЕНИЯ

### 🤖 **6 Advanced N8N Workflows**
- **Document Processing Pipeline** - автоматическая обработка документов
- **RAG Query Automation** - умные поисковые запросы с AI
- **Batch Processing** - массовая обработка до 50 файлов
- **Error Handling & Notifications** - централизованная обработка ошибок
- **System Monitoring** - автоматический мониторинг сервисов
- **Email Integration** - профессиональные уведомления

### 🔐 **Production Security & SSL**
- Let's Encrypt интеграция
- Enterprise-grade security headers
- Multi-domain SSL поддержка
- Network isolation

### 🚀 **Deployment & Automation**
- Auto-Import система для workflows
- Production deployment scripts (Bash/PowerShell)
- Comprehensive health checks
- Monitoring & analytics

### 🔗 **API Enhancements**
- 5 новых webhook endpoints
- RESTful API design
- Rate limiting готовность
- Automated error handling

## 🎯 QUICK START

```bash
# Клонирование и запуск
git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git
cd N8N-AI-Starter-Kit
./scripts/setup.sh --generate-only
docker-compose --profile cpu up -d

# Доступ к сервисам
echo "N8N: http://localhost:5678"
echo "Web Interface: http://localhost:8002"
echo "Document Processor: http://localhost:8001"
```

## 📋 MIGRATION FROM v1.1.3
- Automatic workflow import при первом запуске
- Обновленная структура конфигурации
- Новые environment variables в env.schema (template.env для обратной совместимости)

## 📚 DOCUMENTATION
- [📖 Complete Setup Guide](./README.md)
- [🚀 Server Deployment](./docs/SERVER_DEPLOYMENT.md)
- [🔧 Troubleshooting](./TROUBLESHOOTING.md)
- [📝 Changelog](./CHANGELOG.md)
EOF

echo -e "${GREEN}=====================================${NC}"
echo ""
echo "6. Отметьте 'Set as the latest release'"
echo "7. Нажмите 'Publish release'"

# Финальная информация
echo -e "\n${GREEN}🎉 АВТОМАТИЧЕСКАЯ ЧАСТЬ ПУБЛИКАЦИИ ЗАВЕРШЕНА!${NC}"
echo -e "${BLUE}📋 Осталось только создать GitHub Release по инструкции выше${NC}"

echo -e "\n${YELLOW}📊 СТАТИСТИКА:${NC}"
echo "- Версия: $VERSION"
echo "- Ветка: $(git branch --show-current)"  
echo "- Последний коммит: $(git rev-parse --short HEAD)"
echo "- Тег создан: $(git tag -l $VERSION)"

echo -e "\n${GREEN}✅ Проект готов к production использованию!${NC}"
