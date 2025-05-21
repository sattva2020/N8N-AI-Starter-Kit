# Руководство по устранению неполадок

## 📋 Типичные проблемы и их решения

В этом руководстве представлены решения для наиболее распространенных проблем, с которыми вы можете столкнуться при установке и использовании N8N AI Starter Kit.

## 🐳 Проблемы с Docker

### Docker не запускается

**Симптомы:**
- Сообщение об ошибке "Cannot connect to the Docker daemon"
- Команды Docker не выполняются

**Решения:**
1. Убедитесь, что служба Docker запущена:
   ```bash
   sudo systemctl start docker
   ```

2. Проверьте, входит ли ваш пользователь в группу docker:
   ```bash
   groups | grep docker
   ```
   
   Если нет, добавьте его и перелогиньтесь:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. Проверьте статус службы Docker:
   ```bash
   sudo systemctl status docker
   ```

### Ошибки с Docker Compose

**Симптомы:**
- Ошибка "docker-compose command not found" или "docker compose command not found"
- Ошибки при запуске профилей

**Решения:**
1. Для старого формата (docker-compose):
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. Для нового формата (docker compose):
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install docker-compose-plugin
   
   # CentOS/RHEL
   sudo yum install docker-compose-plugin
   ```

3. Проверьте установку:
   ```bash
   docker-compose --version
   # или
   docker compose version
   ```

## 🔒 Проблемы с SSL и доменами

### Невозможно получить SSL-сертификат

**Симптомы:**
- Traefik не может получить сертификат Let's Encrypt
- Сообщения об ошибках в логах Traefik

**Решения:**
1. Убедитесь, что ваш домен правильно настроен и указывает на IP-адрес вашего сервера:
   ```bash
   dig +short yourdomain.com
   ```

2. Проверьте доступность портов 80 и 443:
   ```bash
   sudo netstat -tulpn | grep -E ':(80|443)'
   ```

3. Проверьте логи Traefik:
   ```bash
   docker compose logs -f traefik
   ```

4. Если используете тестовый домен, измените настройки в docker-compose.yml:
   - Измените `--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory` на `--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory`

5. Убедитесь, что указали правильный email в .env файле (ACME_EMAIL).

### Службы недоступны по доменным именам

**Симптомы:**
- Службы запущены, но недоступны по URL
- Браузер отображает ошибки "Сайт не найден"

**Решения:**
1. Проверьте правильность DNS-записей:
   ```bash
   ping n8n.yourdomain.com
   ```

2. Проверьте статус контейнеров:
   ```bash
   docker compose ps
   ```

3. Проверьте сетевые настройки Docker:
   ```bash
   docker network ls
   docker network inspect frontend-network
   ```

4. Убедитесь, что Traefik правильно настроен в docker-compose.yml и все службы имеют правильные метки.

## 💾 Проблемы с данными и хранением

### Потеря данных после перезапуска

**Симптомы:**
- Данные исчезают после остановки и запуска контейнеров
- Настройки сбрасываются

**Решения:**
1. Убедитесь, что все тома правильно настроены в docker-compose.yml.

2. Проверьте, существуют ли каталоги данных:
   ```bash
   ls -la ./data/
   ```

3. Проверьте права доступа к каталогам данных:
   ```bash
   sudo chown -R $(id -u):$(id -g) ./data/
   ```

4. Явно создайте тома Docker:
   ```bash
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
   ```bash
   df -h
   ```

2. Очистите неиспользуемые образы и контейнеры:
   ```bash
   docker system prune -a
   ```

3. Очистите логи Docker:
   ```bash
   sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
   ```

4. Рассмотрите возможность использования внешнего хранилища для данных.

## 🖥️ Проблемы с сервисами

### N8N не запускается или недоступен

**Симптомы:**
- N8N недоступен через веб-интерфейс
- Ошибки в логах n8n

**Решения:**
1. Проверьте логи n8n:
   ```bash
   docker compose logs -f n8n
   ```

2. Убедитесь, что база данных PostgreSQL запущена и доступна:
   ```bash
   docker compose ps postgres
   ```

3. Проверьте переменные окружения в .env файле для n8n и postgres.

4. Перезапустите n8n:
   ```bash
   docker compose restart n8n
   ```

### Проблемы с Ollama

**Симптомы:**
- Не удается загрузить или запустить модели
- Ошибки в логах Ollama

**Решения:**
1. Проверьте логи Ollama:
   ```bash
   docker compose logs -f ollama
   ```

2. Убедитесь, что у вас достаточно ОЗУ для запуска выбранной модели.

3. Для GPU пользователей:
   - Убедитесь, что вы используете правильный профиль (gpu-nvidia или gpu-amd)
   - Проверьте, что nvidia-container-toolkit установлен и настроен
   - Проверьте доступность GPU внутри контейнера:
     ```bash
     docker exec -it ollama nvidia-smi
     ```

4. Попробуйте запустить меньшую модель для тестирования.

### Проблемы с базой данных

**Симптомы:**
- Ошибки "Connection refused" в логах сервисов
- Сервисы не могут подключиться к базе данных

**Решения:**
1. Проверьте статус PostgreSQL:
   ```bash
   docker compose ps postgres
   docker compose logs -f postgres
   ```

2. Убедитесь, что переменные окружения для подключения к БД правильные в .env файле.

3. Проверьте, доступна ли база данных изнутри сети Docker:
   ```bash
   docker exec -it n8n sh -c "ping postgres"
   ```

4. Проверьте, созданы ли необходимые базы данных:
   ```bash
   docker exec -it postgres psql -U root -c "\l"
   ```

## 🔄 Проблемы с обновлением и миграцией

### Проблемы при обновлении

**Симптомы:**
- Ошибки при запуске после обновления
- Несовместимость версий

**Решения:**
1. Создайте резервную копию всех данных перед обновлением:
   ```bash
   cp -r ./data ./data_backup_$(date +%Y%m%d)
   cp .env .env_backup_$(date +%Y%m%d)
   ```

2. Обновляйте постепенно, а не сразу на последнюю версию.

3. Проверьте журнал изменений каждого компонента для выявления несовместимых изменений.

4. При необходимости откатитесь к предыдущей версии:
   ```bash
   docker compose down
   # восстановите данные из резервной копии
   docker compose --profile <profile_name> up -d
   ```

## 🔍 Проблемы с системными ресурсами

### Высокая загрузка CPU/RAM

**Симптомы:**
- Система работает медленно
- OOM Killer останавливает контейнеры

**Решения:**
1. Мониторинг ресурсов:
   ```bash
   docker stats
   ```

2. Ограничьте ресурсы для контейнеров в docker-compose.yml:
   ```yaml
   services:
     ollama:
       deploy:
         resources:
           limits:
             cpus: '2'
             memory: 4G
   ```

3. Используйте базовый профиль cpu для уменьшения количества запущенных сервисов.

4. Увеличьте размер swap-файла:
   ```bash
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

### Проблемы с GPU

**Симптомы:**
- GPU не обнаруживается в контейнерах
- Ошибки при использовании GPU-профилей

**Решения:**
1. Для NVIDIA GPU:
   - Убедитесь, что драйверы NVIDIA установлены:
     ```bash
     nvidia-smi
     ```
   - Установите nvidia-container-toolkit:
     ```bash
     distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
     curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
     curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
     sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
     sudo systemctl restart docker
     ```

2. Для AMD GPU:
   - Убедитесь, что драйверы ROCm установлены:
     ```bash
     rocm-smi
     ```
   - Проверьте совместимость версии ROCm с Docker.

## 🛠️ Прочие проблемы

### Скрипт setup.sh завершается с ошибкой

**Симптомы:**
- Скрипт setup.sh не выполняется до конца
- Выводятся сообщения об ошибках

**Решения:**
1. Запустите скрипт с отладкой:
   ```bash
   bash -x scripts/setup.sh
   ```

2. Проверьте права доступа к скрипту:
   ```bash
   chmod +x scripts/setup.sh
   ```

3. Убедитесь, что у вас установлены все необходимые утилиты (curl, openssl).

4. Проверьте наличие свободного места на диске:
   ```bash
   df -h
   ```

### Конфликты портов

**Симптомы:**
- Сервисы не запускаются из-за занятых портов
- Ошибки "port is already allocated"

**Решения:**
1. Проверьте, какие порты используются:
   ```bash
   sudo netstat -tulpn
   ```

2. Измените используемые порты в docker-compose.yml, если необходимо.

3. Остановите конфликтующие сервисы:
   ```bash
   sudo systemctl stop nginx  # пример для Nginx
   ```

4. Настройте Traefik для работы на других портах:
   В docker-compose.yml измените:
   ```yaml
   ports:
     - "8080:80"
     - "8443:443"
   ```

## Использование тега latest для Docker-образов

**С мая 2025 года все сервисы N8N AI Starter Kit используют только тег `latest` для Docker-образов.**

### Преимущества:
- Минимум ошибок с отсутствием манифестов или устаревшими версиями
- Упрощение поддержки и обновления
- Быстрый доступ к последним улучшениям

### Возможные недостатки:
- Иногда новые версии могут содержать несовместимые изменения
- Возможны неожиданные сбои при резких обновлениях

### Рекомендации:
- Если после обновления latest возникают ошибки, зафиксируйте стабильный тег для проблемного сервиса в соответствующем compose-файле
- Для обновления используйте:
  ```powershell
  docker compose pull && docker compose up -d
  ```
- При возникновении ошибок с отсутствием манифеста убедитесь, что используется тег latest

## 📞 Где получить дополнительную помощь

Если вы не нашли решение вашей проблемы в этом руководстве:

1. Проверьте логи всех сервисов:
   ```bash
   docker compose logs
   ```

2. Создайте issue в репозитории проекта с подробным описанием проблемы, логами и шагами для воспроизведения.

3. Присоединяйтесь к сообществу N8N в Slack или Discord для получения помощи от других пользователей.

4. Поищите решение на форумах Docker и n8n.

---

Это руководство будет обновляться по мере выявления новых распространенных проблем и их решений. Если у вас есть предложения по дополнению, пожалуйста, создайте pull request или issue в репозитории проекта.
