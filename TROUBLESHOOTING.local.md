# Устранение неполадок N8N AI Starter Kit

## Общие проблемы и решения

### Docker и Docker Compose

- **Ошибка "Permission denied"**
  - Убедитесь, что пользователь добавлен в группу docker: `sudo usermod -aG docker $USER`
  - Перезагрузите систему или выполните: `newgrp docker`

- **Проблемы с DNS в контейнерах**
  - Создайте/измените файл `/etc/docker/daemon.json`:
    ```json
    {
      "dns": ["8.8.8.8", "8.8.4.4"]
    }
    ```
  - Перезапустите Docker: `sudo systemctl restart docker`

- **Ошибка "Error starting userland proxy"**
  - Порты уже используются другими приложениями
  - Проверьте занятые порты: `netstat -tuln` или `lsof -i :80` (для порта 80)

### Traefik и SSL

- **Проблемы с получением SSL-сертификатов**
  - Убедитесь, что порты 80 и 443 доступны из интернета
  - Проверьте правильность настройки DNS для вашего домена
  - Используйте staging-режим Let's Encrypt (добавьте `--acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory` в параметры Traefik)

- **Ошибка "too many certificates already issued"**
  - У Let's Encrypt есть ограничения на количество сертификатов. Подождите неделю или используйте другой домен

### N8N и другие сервисы

- **N8N не может подключиться к Postgres**
  - Убедитесь, что контейнер postgres запущен: `docker ps | grep postgres`
  - Проверьте логи postgres: `docker logs n8n-ai-starter-kit-postgres`

- **Проблемы с Ollama**
  - Для работы с GPU убедитесь, что установлен nvidia-container-toolkit
  - Для больших моделей увеличьте лимиты памяти в docker-compose.override.yml

- **Недостаточно памяти или CPU**
  - Используйте базовый профиль: `docker compose --profile cpu up -d`
  - Закройте другие ресурсоемкие программы
  - Увеличьте размер swap-файла в Linux

## Полезные команды

- Просмотр логов: `docker compose logs -f [service_name]`
- Перезапуск сервиса: `docker compose restart [service_name]`
- Проверка статуса контейнеров: `docker compose ps`
- Проверка сети Docker: `docker network inspect n8n-ai-starter-kit_default`
- Проверка использования ресурсов: `docker stats`

## Контактная информация

- GitHub: https://github.com/n8n-io/n8n
- Документация: https://docs.n8n.io/
- Telegram: https://t.me/n8n_ru

Создан Sat, Jun 28, 2025 12:58:31 PM
