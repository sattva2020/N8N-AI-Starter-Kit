#!/bin/bash
# filepath: scripts/preload-models.sh

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "      Предварительная загрузка моделей Ollama       "
echo -e "${BLUE}====================================================${NC}"

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker не установлен. Пожалуйста, установите Docker перед запуском этого скрипта.${NC}"
    exit 1
fi

# Проверка наличия файла конфигурации моделей
CONFIG_FILE="config/ollama-models.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Файл со списком моделей не найден. Создаем стандартный файл...${NC}"
    mkdir -p config
    cat > "$CONFIG_FILE" << EOL
# Список моделей для предварительной загрузки в Ollama
# Одна модель на строку, строки с # игнорируются

# Рекомендуемые базовые модели (раскомментируйте нужные)
llama3
# llama3:8b
# gemma:2b
# mistral

# Специализированные модели (требуют больше ресурсов)
# codellama:7b
# dolphin-mistral
# neural-chat
EOL
    echo -e "${GREEN}Создан файл конфигурации моделей: $CONFIG_FILE${NC}"
fi

echo -e "\n${BLUE}Доступные модели для загрузки:${NC}"
grep -v "^#" "$CONFIG_FILE" | sed '/^\s*$/d' | nl

# Предложить выбор: загрузить все или выбрать конкретные
echo -e "\n${YELLOW}Выберите опцию загрузки:${NC}"
echo "1) Загрузить все активные модели из файла конфигурации"
echo "2) Выбрать модели для загрузки"
echo "3) Редактировать файл конфигурации моделей"
echo "4) Выход"

read -p "Ваш выбор (1-4): " choice

case $choice in
    1)
        echo -e "\n${BLUE}Запуск загрузки всех моделей...${NC}"
        docker run --rm -v "$(pwd)/config/ollama-models.txt:/models.txt" \
                   -v ollama_data:/root/.ollama \
                   ollama/ollama:latest sh -c '
                       for model in $(grep -v "^#" /models.txt | sed "/^\s*$/d"); do
                           echo "Загрузка модели: $model"
                           ollama pull "$model"
                       done
                   '
        ;;
    2)
        models=()
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
                models+=("$line")
            fi
        done < "$CONFIG_FILE"
        
        echo -e "\n${BLUE}Выберите модели для загрузки (введите номера через пробел):${NC}"
        for i in "${!models[@]}"; do
            echo "$((i+1))) ${models[$i]}"
        done
        
        read -p "Номера моделей: " -a selected
        
        if [ ${#selected[@]} -eq 0 ]; then
            echo -e "${YELLOW}Модели не выбраны. Выход.${NC}"
            exit 0
        fi
        
        selected_models=""
        for num in "${selected[@]}"; do
            index=$((num-1))
            if [ "$index" -ge 0 ] && [ "$index" -lt "${#models[@]}" ]; then
                selected_models+="${models[$index]} "
            fi
        done
        
        echo -e "\n${BLUE}Загрузка выбранных моделей: $selected_models${NC}"
        docker run --rm -v "ollama_data:/root/.ollama" \
                   ollama/ollama:latest sh -c "
                       for model in $selected_models; do
                           echo \"Загрузка модели: \$model\"
                           ollama pull \"\$model\"
                       done
                   "
        ;;
    3)
        if command -v nano &> /dev/null; then
            nano "$CONFIG_FILE"
        elif command -v vim &> /dev/null; then
            vim "$CONFIG_FILE"
        else
            echo -e "${YELLOW}Текстовый редактор не найден. Пожалуйста, откройте файл $CONFIG_FILE вручную.${NC}"
        fi
        ;;
    4)
        echo -e "${BLUE}Выход из программы.${NC}"
        exit 0
        ;;
    *)
        echo -e "${YELLOW}Неверный выбор. Выход.${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Загрузка моделей завершена! Теперь система будет работать быстрее при первом запуске.${NC}"
echo -e "${BLUE}Вы можете запустить систему командой:${NC} ./scripts/start.sh cpu"