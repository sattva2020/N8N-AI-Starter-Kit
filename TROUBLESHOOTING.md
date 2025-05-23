# Устранение неполадок N8N AI Starter Kit

В этом руководстве описаны наиболее распространенные проблемы и их решения для N8N AI Starter Kit.

<p align="center">
  <a href="./README.md">
    <img src="https://img.shields.io/badge/Вернуться_к_README-blue?style=for-the-badge" alt="Вернуться к README">
  </a>
</p>

## Содержание
1. [Проблемы с развертыванием](#проблемы-с-развертыванием)
2. [Проблемы с Docker](#проблемы-с-docker)
3. [Проблемы с Ollama](#проблемы-с-ollama)
4. [Проблемы с n8n](#проблемы-с-n8n)
5. [Проблемы с базой данных](#проблемы-с-базой-данных)
6. [Проблемы с SSL-сертификатами](#проблемы-с-ssl-сертификатами)
7. [Проблемы с доменами и доступом](#проблемы-с-доменами-и-доступом)
8. [Проблемы с данными и хранением](#проблемы-с-данными-и-хранением)
9. [Проблемы с производительностью](#проблемы-с-производительностью)
10. [Проблемы с портами](#проблемы-с-портами)
11. [Проблемы с обновлением и миграцией](#проблемы-с-обновлением-и-миграцией)
12. [Использование тега latest для Docker-образов](#использование-тега-latest-для-docker-образов)
13. [Автоматическое исправление распространенных ошибок](#автоматическое-исправление-распространенных-ошибок)

> [!TIP]
> Для быстрого решения распространенных проблем смотрите [Распространенные проблемы и их решения](./docs/COMMON_ISSUES.md)

## Проблемы с развертыванием

### Ошибка "No Space Left On Device"
**Симптомы**: Ошибки при запуске контейнеров, особенно при загрузке моделей Ollama

**Решение**:
1. Очистите неиспользуемые Docker ресурсы:
   ```bash
   docker system prune --all --volumes
   ```

2. Проверьте доступное пространство:
   ```powershell
   Get-PSDrive -PSProvider FileSystem
   ```

### Ошибка "fatal error: concurrent map writes" при запуске Docker Compose
**Симптомы**: Docker Compose выдает панику с ошибкой `fatal error: concurrent map writes` при запуске контейнеров

**Решение**:
1. **Обновите Docker и Docker Compose до последней версии**:
   ```bash
   sudo apt update
   sudo apt install --only-upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
   Проверьте версии после обновления:
   ```bash
   docker --version
   docker compose version
   ```

2. **Перезапустите службу Docker**:
   ```powershell
   Restart-Service docker
   ```

3. **Очистите системные ресурсы Docker**:
   > **Предупреждение**: Эта команда удалит все неиспользуемые контейнеры, сети, образы и, возможно, кэш сборки и тома.
   ```powershell
   docker system prune -a -f --volumes
   ```

4. **Проверьте конфигурацию файла `.env`**:
   Убедитесь, что все необходимые переменные окружения правильно определены. Предупреждения вида `WARN[0000] The "SrhUjW1v" variable is not set` указывают на проблемы с переменными окружения.

5. **Запустите с ограниченным параллелизмом**:
   ```powershell
   $env:COMPOSE_PARALLEL_LIMIT=1; docker-compose --profile cpu up -d
   ```
   
   Или используйте скрипт автоматического исправления:
   ```powershell
   .\scripts\fix-and-start.ps1
   ```

### Проблемы с переменными окружения
**Симптомы**: Предупреждения о неопределенных переменных, таких как "JWT_SECRET", "ANON_KEY", "SERVICE_ROLE_KEY"

**Решение**:
Запустите скрипт для исправления переменных окружения:
```powershell
.\scripts\fix-env-vars.ps1
```

Подробнее см. в разделе [Распространенные проблемы](./docs/COMMON_ISSUES.md).

### Конфликт сетей в Docker Compose
**Симптомы**: Ошибка "networks.backend conflicts with imported resource"

**Решение**:
Запустите скрипт для исправления конфликтов сетей:
```powershell
.\scripts\fix-and-start.ps1
```
```

Подробнее см. в разделе [Конфликты сетей Docker](./docs/COMMON_ISSUES.md#конфликты-сетей-docker).

## Проблемы с Docker

### Docker не запускается

**Симптомы:**
- Сообщение об ошибке "Cannot connect to the Docker daemon"
- Команды Docker не выполняются

**Решения:**
1. Убедитесь, что служба Docker запущена:
   ```powershell
   Start-Service docker
   ```

2. Проверьте статус службы Docker:
   ```powershell
   Get-Service docker
   ```

3. Перезапустите службу Docker:
   ```powershell
   Restart-Service docker
   ```

### Ошибки с Docker Compose

**Симптомы:**
- Ошибка "docker-compose command not found" или "docker compose command not found"
- Ошибки при запуске профилей

**Решения:**
1. Убедитесь, что Docker Compose установлен и обновлен до последней версии.

2. Для Windows проверьте, что Docker Desktop установлен и запущен.

3. Проверьте установку:
   ```powershell
   docker-compose --version
   # или
   docker compose version
   ```

## Проблемы с Ollama

### Модели не загружаются или загружаются медленно
**Симптомы**: Модели Ollama не загружаются или загрузка занимает очень много времени

**Решение**:
1. Проверьте, что контейнер Ollama имеет доступ к интернету
2. Увеличьте таймаут для загрузки моделей в `docker-compose.yml`:
   ```yaml
   ollama-pull:
     environment:
       - DOWNLOAD_TIMEOUT=1800  # Увеличьте до 30 минут (или больше)
   ```
3. Если вы находитесь в регионе с ограниченным доступом, рассмотрите возможность использования VPN

### Ошибки при использовании GPU
**Симптомы**: Ollama не может получить доступ к GPU, или возникают ошибки CUDA

**Решение**:
1. Убедитесь, что у вас установлены правильные драйверы NVIDIA
2. Проверьте установку NVIDIA Container Toolkit:
   ```bash
   sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```
3. Проверьте доступность GPU из контейнера:
   ```bash
   docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
   ```

## Проблемы с n8n

### Проблема с подключением к локальным сервисам
**Симптомы**: n8n не может подключиться к другим сервисам в сети Docker

**Решение**:
1. Убедитесь, что используете правильные имена хостов (имена сервисов Docker) вместо localhost:
   - Для Ollama используйте `ollama:11434`
   - Для Postgres используйте `postgres:5432`
   - Для Qdrant используйте `qdrant:6333`

2. Проверьте, что все сервисы находятся в одной Docker-сети

### Проблемы с импортом демонстрационных данных
**Симптомы**: Демонстрационные данные (credentials, workflows) не импортируются или вызывают ошибки

**Решение**:
1. Проверьте права доступа к директории с демонстрационными данными:
   ```bash
   sudo chown -R 1000:1000 ./n8n/demo-data
   ```

2. Если используете Mac с M1/M2, проверьте файл `n8n/demo-data/credentials/xHuYe0MDGOs9IpBW.json` и удостоверьтесь, что он настроен правильно для подключения к Ollama.

## Проблемы с базой данных

### Ошибка аутентификации PostgreSQL
**Симптомы**: Ошибка "password authentication failed" в логах

**Решение**:
1. Проверьте, совпадают ли учетные данные в `.env` файле с теми, которые использовались при инициализации базы данных.
2. Если вы изменяли учетные данные после первоначальной настройки, вам может потребоваться удалить существующий том базы данных:
   ```bash
   docker compose down -v
   docker volume rm n8n-ai-starter-kit_postgres_storage
   docker compose up -d
   ```

### Ошибка подключения Zep к PostgreSQL
**Симптомы**: В логах `zep-ce-postgres` видны ошибки типа `password authentication failed for user "${ZEP_POSTGRES_USER}"` или `Role "${ZEP_POSTGRES_USER}" does not exist`

**Решение**:
1. Проверьте, что сервис Zep имеет доступ к переменным окружения из файла `.env`. В `zep-compose.yaml` добавьте:
   ```yaml
   services:
     zep:
       env_file:
         - .env
   ```

2. Убедитесь, что учетные данные в `.env` соответствуют тем, что использовались при инициализации базы данных:
   ```properties
   ZEP_POSTGRES_USER=postgres
   ZEP_POSTGRES_PASSWORD=postgres
   ZEP_POSTGRES_DB=postgres
   ```

3. Если учетные данные были изменены, удалите том базы данных и перезапустите:
   ```bash
   docker volume rm n8n-ai-starter-kit_zep-db
   docker compose up -d
   ```

## Проблемы с SSL-сертификатами

### Ошибка получения сертификата Let's Encrypt
**Симптомы**: Traefik не может получить сертификаты, ошибки в логах о проверке домена

**Решение**:
1. Убедитесь, что порты 80 и 443 проброшены и доступны из интернета
2. Проверьте, что указанные домены правильно настроены в DNS и указывают на ваш сервер
3. Проверьте конфигурацию Traefik:
   ```bash
   docker logs traefik
   ```
4. Временно включите режим отладки в Traefik:
   ```yaml
   command:
     - "--log.level=DEBUG"
   ```

### Сертификат считается небезопасным
**Симптомы**: Браузер предупреждает о небезопасном соединении

**Решение**:
1. Проверьте, использует ли Traefik правильный эндпоинт для ACME вызовов
2. Обновите контейнер Traefik и удалите старые сертификаты:
   ```powershell
   docker compose down traefik
   docker volume rm n8n-ai-starter-kit_traefik_letsencrypt
   docker compose up -d traefik
   ```

## Проблемы с доменами и доступом

### Службы недоступны по доменным именам

**Симптомы:**
- Службы запущены, но недоступны по URL
- Браузер отображает ошибки "Сайт не найден"

**Решения:**
1. Проверьте правильность DNS-записей:
   ```powershell
   nslookup n8n.yourdomain.com
   ```

2. Проверьте статус контейнеров:
   ```powershell
   docker compose ps
   ```

3. Проверьте сетевые настройки Docker:
   ```powershell
   docker network ls
   docker network inspect frontend
   ```

4. Убедитесь, что Traefik правильно настроен в docker-compose.yml и все службы имеют правильные метки.

## Проблемы с данными и хранением

### Потеря данных после перезапуска

**Симптомы:**
- Данные исчезают после остановки и запуска контейнеров
- Настройки сбрасываются

**Решения:**
1. Убедитесь, что все тома правильно настроены в docker-compose.yml.

2. Проверьте, существуют ли каталоги данных:
   ```powershell
   Get-ChildItem -Path .\data\
   ```

3. Проверьте права доступа к каталогам данных.

4. Явно создайте тома Docker:
   ```powershell
   docker volume create n8n_storage
   docker volume create postgres_storage
   # и т.д. для всех используемых томов
   ```

### Недостаточно места на диске

**Симптомы:**
- Ошибки "No space left on device"
- Контейнеры останавливаются неожиданно

**Решения:**
1. Проверьте доступное пространство:
   ```powershell
   Get-PSDrive -PSProvider FileSystem
   ```

2. Очистите неиспользуемые образы и контейнеры:
   ```powershell
   docker system prune -a
   ```

3. Рассмотрите возможность использования внешнего хранилища для данных.
2. Обновите контейнер Traefik и удалите старые сертификаты:
   ```bash
   docker compose down traefik
   docker volume rm n8n-ai-starter-kit_traefik_letsencrypt
   docker compose up -d traefik
   ```

## Проблемы с производительностью

### Высокое потребление памяти
**Симптомы**: Система замедляется, OOM-killer завершает процессы

**Решение**:
1. Ограничьте ресурсы для контейнеров в `docker-compose.yml`:
   ```yaml
   services:
     ollama:
       deploy:
         resources:
           limits:
             memory: 4G
   ```

2. Если вы не используете GPU, уменьшите количество потоков, используемых Ollama:
   ```bash
   echo 'OLLAMA_NUM_THREADS=4' >> .env
   ```

3. Используйте базовый профиль cpu для запуска только необходимых сервисов:
   ```bash
   docker compose --profile cpu up -d
   ```

### Медленный отклик LLM моделей
**Симптомы**: Генерация текста Ollama занимает очень много времени

**Решение**:
1. Используйте более легкие модели (например, llama3:8b вместо llama3)
2. Если доступна видеокарта, убедитесь что используется профиль GPU:
   ```bash
   docker compose --profile gpu-nvidia up -d
   ```
3. Увеличьте количество ядер CPU, доступных для Ollama:
   ```yaml
   services:
     ollama:
       deploy:
         resources:
           limits:
             cpus: '4'
   ```

### Ошибка при подключении к сервисам через Traefik
**Симптомы**: Сообщения об ошибках подключения на стороне клиента или в логах Traefik

**Решение**:
1. Проверьте, что все сервисы запущены:
   ```bash
   docker compose ps
   ```
2. Убедитесь, что внешние домены правильно настроены:
   ```bash
   ping n8n.ваш-домен.com
   ```
3. Проверьте правила маршрутизации в Traefik:
   ```bash
   docker exec -it traefik traefik healthcheck
   ```

## Проблемы с портами

### Конфликты портов

**Симптомы:**
- Ошибки вида "port is already allocated" или "bind: address already in use"
- Службы запускаются, но недоступны
- Некоторые сервисы завершаются с ошибкой

**Решения:**
1. Проверьте, какие порты уже используются в системе:
   ```powershell
   # Windows
   netstat -ano | findstr LISTENING
   
   # Linux/macOS
   sudo lsof -i -P -n | grep LISTEN
   ```

2. Измените порты в файле `.env` или соответствующем compose-файле:
   ```yaml
   services:
     n8n:
       ports:
         - "5678:5678"  # Измените на "5679:5678", если порт 5678 занят
   ```

3. Остановите конфликтующие сервисы:
   ```powershell
   # Windows - найдите PID процесса использующего порт и остановите его
   Get-Process -Id (Get-NetTCPConnection -LocalPort 5678).OwningProcess | Stop-Process -Force
   
   # Linux/macOS
   sudo kill $(sudo lsof -t -i:5678)
   ```

### Порты блокируются брандмауэром

**Симптомы:**
- Службы запущены, но недоступны извне
- Подключения отбрасываются или таймаут

**Решения:**
1. Проверьте настройки брандмауэра Windows:
   ```powershell
   # Проверка правил брандмауэра
   Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' } | Format-Table Name, DisplayName, Direction, Action -AutoSize
   
   # Добавление разрешения для порта
   New-NetFirewallRule -DisplayName "Allow N8N" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5678
   ```

2. Для Linux проверьте настройки UFW или iptables:
   ```bash
   # UFW
   sudo ufw allow 5678/tcp
   
   # iptables
   sudo iptables -A INPUT -p tcp --dport 5678 -j ACCEPT
   ```

3. Проверьте сетевую доступность с другого устройства:
   ```powershell
   # Windows
   Test-NetConnection -ComputerName your-server-ip -Port 5678
   
   # Linux/macOS
   nc -zv your-server-ip 5678
   ```

### Проблемы с проксированием портов через Traefik

**Симптомы:**
- Сервисы недоступны через Traefik, но работают при прямом подключении к портам
- Ошибки таймаута или соединения в логах Traefik

**Решения:**
1. Проверьте метки Traefik в docker-compose.yml:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.n8n.rule=Host(`n8n.yourdomain.com`)"
     - "traefik.http.services.n8n.loadbalancer.server.port=5678"
   ```

2. Убедитесь, что Traefik имеет доступ к Docker сокету:
   ```yaml
   services:
     traefik:
       volumes:
         - "/var/run/docker.sock:/var/run/docker.sock"
   ```

3. Проверьте логи Traefik на наличие ошибок:
   ```bash
   docker logs traefik
   ```

4. Временно включите режим отладки в Traefik:
   ```yaml
   command:
     - "--log.level=DEBUG"
   ```

## Автоматическое исправление распространенных ошибок

N8N AI Starter Kit включает набор автоматизированных скриптов для исправления наиболее распространенных проблем. Эти скрипты могут сэкономить время и упростить устранение неполадок.

### Скрипт fix-and-start

**Назначение**: Исправляет конфликты сетей Docker и другие распространенные ошибки при запуске.

**Использование**:
```powershell
# Windows
.\scripts\fix-and-start.ps1

# Linux/macOS
./scripts/fix-and-start.sh
```

**Что делает скрипт**:
1. Останавливает все контейнеры
2. Удаляет проблемные сети Docker
3. Пересоздает сети с правильными настройками
4. Запускает систему с ограниченным параллелизмом

### Скрипт fix-env-vars

**Назначение**: Исправляет проблемы с отсутствующими или неправильными переменными окружения.

**Использование**:
```powershell
# Windows
.\scripts\fix-env-vars.ps1

# Linux/macOS
./scripts/fix-env-vars.sh
```

**Что делает скрипт**:
1. Проверяет наличие файла `.env`
2. Генерирует отсутствующие переменные с безопасными значениями
3. Исправляет распространенные ошибки в формате и значениях

### Скрипт start-with-limited-parallelism

**Назначение**: Запускает систему с ограниченным параллелизмом, что помогает избежать ошибки "concurrent map writes".

**Использование**:
```powershell
# Windows
.\scripts\start-with-limited-parallelism.ps1

# Linux/macOS
./scripts/start-with-limited-parallelism.sh
```

**Что делает скрипт**:
1. Устанавливает переменную `COMPOSE_PARALLEL_LIMIT=1`
2. Запускает Docker Compose с опцией `--profile`
3. После запуска проверяет статус контейнеров

### Скрипт diagnose

**Назначение**: Собирает информацию о системе и возможных проблемах для диагностики.

**Использование**:
```powershell
# Linux/macOS
./scripts/diagnose.sh

# Windows
# Запустите PowerShell как администратор
```

**Что делает скрипт**:
1. Проверяет версии Docker и Docker Compose
2. Собирает конфигурацию и логи всех контейнеров
3. Проверяет наличие типичных проблем
4. Создает отчет для облегчения диагностики

### Скрипт clean-docker

**Назначение**: Выполняет глубокую очистку ресурсов Docker для освобождения места и устранения конфликтов.

**Использование**:
```powershell
# Linux/macOS
./scripts/clean-docker.sh

# Windows
# Примечание: Для Windows используйте команды Docker напрямую
# docker system prune -a --volumes
```

**Что делает скрипт**:
1. Останавливает все контейнеры
2. Удаляет неиспользуемые образы, контейнеры, тома и сети
3. Очищает кэш сборки
4. Показывает освобожденное место

> [!WARNING]
> Скрипт clean-docker.sh удаляет неиспользуемые ресурсы Docker. Убедитесь, что у вас есть резервные копии данных перед его запуском.