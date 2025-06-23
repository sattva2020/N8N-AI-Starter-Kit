#!/bin/bash

# Простое и быстрое решение для вашей ситуации

echo "🔧 Быстрое исправление проблемы с git"
echo "====================================="
echo

# Проверяем, есть ли .git директория
if [[ ! -d ".git" ]]; then
    echo "Инициализация git репозитория..."
    git init
    git remote add origin https://github.com/sattva2020/N8N-AI-Starter-Kit.git
    echo "✅ Git репозиторий инициализирован"
else
    echo "✅ Git репозиторий уже существует"
fi

# Создаем .env если нет
if [[ ! -f ".env" ]] && [[ -f "template.env" ]]; then
    echo "Создание .env файла..."
    cp template.env .env
    echo "✅ .env файл создан"
fi

echo
echo "🚀 Теперь можете продолжить:"
echo "   ./scripts/ubuntu-vm-deploy.sh"
echo
echo "Или запустить напрямую:"
echo "   docker compose --profile cpu up -d"
