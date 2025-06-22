# Автоматическая установка на Ubuntu

Для автоматической установки N8N-AI-Starter-Kit на Ubuntu используйте наш готовый скрипт.

## Быстрая установка

```bash
# Скачайте и запустите скрипт установки
curl -fsSL https://raw.githubusercontent.com/sattva2020/N8N-AI-Starter-Kit/main/scripts/ubuntu-install.sh | bash
```

## Что делает скрипт

1. **Проверяет систему** — убеждается, что это Ubuntu
2. **Обновляет систему** — выполняет `apt update` и `apt upgrade`
3. **Устанавливает зависимости** — curl, git, wget и другие необходимые пакеты
4. **Устанавливает Docker** — последнюю версию Docker и Docker Compose
5. **Клонирует проект** — загружает N8N-AI-Starter-Kit в `~/N8N-AI-Starter-Kit`
6. **Настраивает права** — делает скрипты исполняемыми
7. **Запускает диагностику** — проверяет готовность системы
8. **Предлагает настройку** — интерактивный мастер первоначальной настройки

## Требования

- Ubuntu 18.04+ (рекомендуется Ubuntu 20.04 или 22.04)
- Права sudo
- Интернет-соединение

## Что понадобится во время установки

Во время интерактивной настройки вас попросят указать:

- **Email** — для генерации SSL сертификатов (Let's Encrypt)
- **Доменное имя** — или `localhost` для локального использования
- **OpenAI API ключ** — для работы с ChatGPT/GPT-4

## После установки

После успешной установки сервисы будут доступны по адресам:

- **n8n**: http://localhost:5678
- **Qdrant**: http://localhost:6333/dashboard
- **Ollama**: http://localhost:11434
- **Traefik Dashboard**: http://localhost:8080

Если настроены домены:
- **n8n**: https://n8n.yourdomain.com
- **Qdrant**: https://qdrant.yourdomain.com  
- **Traefik**: https://traefik.yourdomain.com

## Профили запуска

Скрипт поддерживает различные профили:

```bash
# Профиль CPU (рекомендуется для серверов без GPU)
./start.sh cpu

# Профиль GPU (требует NVIDIA GPU)
./start.sh gpu

# Полный профиль (все сервисы)
./start.sh developer
```

## Полезные команды

```bash
# Перейти в папку проекта
cd ~/N8N-AI-Starter-Kit

# Посмотреть статус сервисов
docker compose ps

# Посмотреть логи
docker compose logs -f

# Остановить все сервисы
docker compose down

# Запустить заново
./start.sh

# Диагностика проблем
./scripts/diagnose.sh
```

## Ручная установка

Если предпочитаете ручную установку, следуйте инструкциям в [UBUNTU_DEPLOYMENT.md](./UBUNTU_DEPLOYMENT.md).

## Решение проблем

### Частые проблемы и их решение:

#### 1. Ошибки Docker образов
```bash
# Ошибка: "manifest not found" 
# Решение: обновите образы
docker compose pull
```

#### 2. Предупреждение об OpenAI API ключе
```bash
# WARN: The "OPENAI_API_KEY" variable is not set
# Решение: настройте API ключ в .env файле
echo "OPENAI_API_KEY=your_api_key_here" >> .env
```

#### 3. Права Docker
```bash
# Ошибка: "permission denied while trying to connect to the Docker daemon"
# Решение: перезапустите сессию или выполните
newgrp docker
# или перелогиньтесь в систему
```

#### 4. Занятые порты
```bash
# Ошибка: "port is already allocated"
# Проверьте какие процессы используют порты
sudo netstat -tulpn | grep :5678
sudo netstat -tulpn | grep :6333

# Остановите конфликтующие сервисы
sudo systemctl stop nginx  # если используется nginx
```

#### 5. Недостаток памяти
```bash
# Для серверов с ограниченной памятью используйте профиль cpu
./start.sh cpu

# Или настройте swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Общее решение проблем:

1. Проверьте логи: `docker compose logs -f`
2. Запустите диагностику: `./scripts/diagnose.sh`
3. Обратитесь к [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
4. Создайте [issue на GitHub](https://github.com/sattva2020/N8N-AI-Starter-Kit/issues)

## Примечания

- После установки Docker может потребоваться перезапуск сессии или выполнение `newgrp docker`
- Для production использования рекомендуется настроить доменное имя и SSL сертификаты
- Скрипт автоматически добавляет пользователя в группу `docker`
