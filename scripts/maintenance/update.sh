#!/bin/bash
# filepath: scripts/update.sh

echo "==================================="
echo "  N8N AI Starter Kit - Обновление  "
echo "==================================="

# Создание резервной копии перед обновлением
echo "Создание резервной копии перед обновлением..."
./scripts/backup.sh

# Обновление репозитория
echo "Получение последних изменений из репозитория..."
git pull

# Обновление образов Docker
echo "Обновление Docker образов..."
docker compose pull

# Перезапуск контейнеров с новыми образами
echo "Перезапуск сервисов с новыми образами..."
docker compose down

# Определение профиля
if [ -n "$1" ]; then
  PROFILE="$1"
  echo "Используется указанный профиль: $PROFILE"
else
  PROFILE="cpu"  # Профиль по умолчанию
  echo "Профиль не указан, используется профиль по умолчанию: $PROFILE"
fi

# Запуск с указанным профилем
docker compose --profile $PROFILE up -d

echo "Обновление успешно завершено!"
echo ""
echo "Доступные профили:"
echo "- cpu        : Стандартный набор на CPU (по умолчанию)"
echo "- developer  : Расширенный набор инструментов для разработки с pgAdmin, JupyterLab и др."
echo "- gpu-nvidia : Стандартный набор с поддержкой NVIDIA GPU"
echo "- gpu-amd    : Стандартный набор с поддержкой AMD GPU"
echo ""
echo "Пример запуска: ./scripts/update.sh developer"