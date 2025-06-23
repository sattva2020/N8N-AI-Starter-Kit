#!/bin/bash

# Простая инструкция для быстрого создания пользователя на Ubuntu VM

echo "================================================="
echo "🚀 N8N AI Starter Kit - Быстрая настройка Ubuntu VM"
echo "================================================="
echo
echo "Текущий пользователь: $(whoami)"
echo

if [[ $EUID -eq 0 ]]; then
    echo "✅ Вы запущены от root - можно создать пользователя"
    echo
    echo "Для создания пользователя выполните:"
    echo "   bash scripts/create-user.sh"
    echo
    echo "После создания пользователя переключитесь на него:"
    echo "   su - n8nuser"
    echo
    echo "И запустите развертывание:"
    echo "   ./scripts/ubuntu-vm-deploy.sh"
else
    echo "ℹ️  Вы работаете под обычным пользователем: $(whoami)"
    echo
    echo "Проверим ваши права:"
    
    # Проверка sudo прав
    if sudo -n true 2>/dev/null; then
        echo "✅ У вас есть sudo права"
    else
        echo "❌ У вас нет sudo прав"
        echo "   Попросите администратора добавить вас в группу sudo:"
        echo "   sudo usermod -aG sudo $(whoami)"
        exit 1
    fi
    
    # Проверка группы docker
    if groups | grep -q docker; then
        echo "✅ Вы в группе docker"
    else
        echo "⚠️  Вы не в группе docker"
        echo "   После установки Docker добавьте себя в группу:"
        echo "   sudo usermod -aG docker $(whoami)"
        echo "   newgrp docker"
    fi
    
    echo
    echo "Вы можете запускать развертывание:"
    echo "   ./scripts/ubuntu-vm-deploy.sh"
fi

echo
echo "================================================="
echo "📚 Полная документация:"
echo "   docs/UBUNTU_VM_COMPLETE_GUIDE.md"
echo "   docs/UBUNTU_USER_SETUP.md"
echo "================================================="
