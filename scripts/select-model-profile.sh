#!/bin/bash
# Скрипт для выбора профиля моделей из ollama-models-config.yml
# filepath: scripts/select-model-profile.sh

CONFIG_FILE="config/ollama-models-config.yml"
OUTPUT_FILE="config/ollama-models.txt"

print_info() {
  echo -e "\033[34mℹ️ $1\033[0m"
}

print_success() {
  echo -e "\033[32m✅ $1\033[0m"
}

print_error() {
  echo -e "\033[31m❌ $1\033[0m"
}

# CONFIG_FILE is optional documentation only. The script will continue even if
# the YAML file is not present (the profiles below are hardcoded). This allows
# the repo to omit the YAML while keeping it available as a helpful reference.
if [ ! -f "$CONFIG_FILE" ]; then
  print_info "Файл конфигурации $CONFIG_FILE не найден — используем встроенные профили. (Опционально)"
fi

echo "🤖 Выбор профиля моделей Ollama"
echo "==============================="
echo ""
echo "Доступные профили:"
echo "1) minimal   - Легкие модели (1.7GB, требует 3GB RAM)"
echo "2) standard  - Стандартные модели (13GB, требует 12GB RAM)"  
echo "3) advanced  - Продвинутые модели (62GB, требует 80GB RAM)"
echo "4) custom    - Выбрать модели вручную"
echo ""

read -p "Выберите профиль (1-4): " choice

case $choice in
  1)
    print_info "Выбран профиль: minimal"
    cat > "$OUTPUT_FILE" << EOF
# Автоматически сгенерировано: профиль minimal
# Общий размер: ~1.7GB, требует 3GB RAM

gemma:2b
nomic-embed-text
EOF
    ;;
  2)
    print_info "Выбран профиль: standard"
    cat > "$OUTPUT_FILE" << EOF
# Автоматически сгенерировано: профиль standard  
# Общий размер: ~13GB, требует 12GB RAM

phi4:14b
nomic-embed-text
llama3:8b
EOF
    ;;
  3)
    print_info "Выбран профиль: advanced"
    cat > "$OUTPUT_FILE" << EOF
# Автоматически сгенерировано: профиль advanced
# Общий размер: ~62GB, требует 80GB RAM

llama3:70b
codellama:34b
phi4:14b
nomic-embed-text
EOF
    ;;
  4)
    print_info "Открытие файла для ручного редактирования..."
    ${EDITOR:-nano} "$OUTPUT_FILE"
    ;;
  *)
    print_error "Некорректный выбор!"
    exit 1
    ;;
esac

print_success "Конфигурация сохранена в $OUTPUT_FILE"
print_info "Для загрузки моделей выполните: ./scripts/preload-models.sh"
