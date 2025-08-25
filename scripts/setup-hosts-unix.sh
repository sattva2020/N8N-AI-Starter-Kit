#!/bin/bash
# N8N AI Starter Kit - Linux/macOS Hosts Setup Script
# Этот скрипт автоматически добавляет/удаляет записи в hosts файл для локальной разработки

set -e

HOSTS_FILE="/etc/hosts"
MARKER="# N8N AI Starter Kit - Local Development Domains"
BACKUP_FILE="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка прав sudo
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}✓ Скрипт запущен с правами root${NC}"
    elif sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✓ Sudo права доступны${NC}"
    else
        echo -e "${RED}ОШИБКА: Требуются права sudo!${NC}"
        echo "Запустите скрипт с sudo или убедитесь, что у вас есть права на редактирование $HOSTS_FILE"
        exit 1
    fi
}

# Создание резервной копии
backup_hosts() {
    echo -e "${BLUE}Создаем резервную копию hosts файла...${NC}"
    sudo cp "$HOSTS_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Резервная копия создана: $BACKUP_FILE${NC}"
}

# Показать меню
show_menu() {
    echo ""
    echo "============================================"
    echo " N8N AI Starter Kit - Настройка Hosts File"
    echo "============================================"
    echo ""
    echo "Выберите действие:"
    echo "1. Добавить записи в hosts файл"
    echo "2. Удалить записи из hosts файла"
    echo "3. Показать текущие записи"
    echo "4. Тестировать подключение"
    echo "5. Восстановить из резервной копии"
    echo "6. Выход"
    echo ""
    read -p "Введите номер (1-6): " choice
}

# Добавить записи
add_entries() {
    echo ""
    echo -e "${BLUE}Проверяем, есть ли уже записи...${NC}"
    
    if grep -q "n8n.example.com" "$HOSTS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Записи уже существуют в hosts файле!${NC}"
        read -p "Хотите их обновить? (y/N): " update
        if [[ $update =~ ^[Yy]$ ]]; then
            remove_entries_silent
        else
            return
        fi
    fi

    echo -e "${BLUE}Добавляем записи в hosts файл...${NC}"
    backup_hosts

    {
        echo ""
        echo "$MARKER"
    echo "127.0.0.1 n8n.example.com"
    echo "127.0.0.1 qdrant.example.com"
    echo "127.0.0.1 traefik.example.com"
    echo "127.0.0.1 doc-processor.example.com"
    echo "127.0.0.1 web.example.com"
    echo "127.0.0.1 ollama.example.com"
    echo "127.0.0.1 pgadmin.example.com"
    echo "127.0.0.1 jupyter.example.com"
    echo "127.0.0.1 graphiti.example.com"
    echo "127.0.0.1 supabase.example.com"
    echo "127.0.0.1 api.example.com"
    echo "127.0.0.1 zep.example.com"
    } | sudo tee -a "$HOSTS_FILE" > /dev/null

    echo -e "${GREEN}УСПЕШНО: Записи добавлены в hosts файл!${NC}"
    echo ""
    echo "Теперь можно запускать N8N AI Starter Kit с доменами .example.com"
    test_connectivity
}

# Удалить записи
remove_entries() {
    remove_entries_silent
    echo -e "${GREEN}УСПЕШНО: Записи удалены из hosts файла!${NC}"
}

remove_entries_silent() {
    echo -e "${BLUE}Удаляем записи из hosts файла...${NC}"
    backup_hosts
    
    # Создаем временный файл без наших записей
    TEMP_FILE=$(mktemp)
    grep -v "example.com" "$HOSTS_FILE" | grep -v "$MARKER" > "$TEMP_FILE"
    sudo cp "$TEMP_FILE" "$HOSTS_FILE"
    rm "$TEMP_FILE"
}

# Показать записи
show_entries() {
    echo ""
    echo "Текущие записи в hosts файле связанные с example.com:"
    echo "========================================================="
    if grep -E "(example.com|$MARKER)" "$HOSTS_FILE" 2>/dev/null; then
        echo ""
    else
        echo "Записи не найдены."
    fi
}

# Тестировать подключение
test_connectivity() {
    echo ""
    echo -e "${BLUE}Тестируем подключение к доменам...${NC}"
    echo ""

    domains=("n8n.example.com" "qdrant.example.com" "traefik.example.com")
    
    for domain in "${domains[@]}"; do
        echo "Проверяем $domain..."
        if ping -c 1 "$domain" 2>/dev/null | grep -q "127.0.0.1"; then
            echo -e "${GREEN}✓ $domain настроен корректно${NC}"
        else
            echo -e "${RED}✗ Ошибка настройки $domain${NC}"
        fi
    done

    echo ""
    echo "Все домены должны резолвиться в 127.0.0.1"
}

# Восстановить из резервной копии
restore_backup() {
    echo ""
    echo -e "${BLUE}Доступные резервные копии:${NC}"
    ls -la /etc/hosts.backup.* 2>/dev/null || {
        echo -e "${YELLOW}Резервные копии не найдены.${NC}"
        return
    }
    
    echo ""
    read -p "Введите полный путь к резервной копии: " backup_path
    
    if [[ -f "$backup_path" ]]; then
        sudo cp "$backup_path" "$HOSTS_FILE"
        echo -e "${GREEN}✓ Hosts файл восстановлен из резервной копии${NC}"
    else
        echo -e "${RED}Файл не найден: $backup_path${NC}"
    fi
}

# Основная функция
main() {
    check_sudo
    
    while true; do
        show_menu
        
        case $choice in
            1)
                add_entries
                ;;
            2)
                remove_entries
                ;;
            3)
                show_entries
                ;;
            4)
                test_connectivity
                ;;
            5)
                restore_backup
                ;;
            6)
                echo ""
                echo -e "${GREEN}Спасибо за использование N8N AI Starter Kit!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор. Попробуйте еще раз.${NC}"
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск
main
