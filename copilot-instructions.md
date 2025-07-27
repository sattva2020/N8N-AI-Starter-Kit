# Инструкция для GitHub Copilot

Перед началом любой работы с этим проектом обязательно:

1. **ИЗУЧИ СТРУКТУРУ**: Прочитай `PROJECT_STRUCTURE_GUIDELINES.md` для понимания организации проекта
2. **СОБЛЮДАЙ ЧИСТОТУ**: Используй `STRUCTURE_QUICK_REFERENCE.md` для быстрой проверки правил
3. **СЛЕДУЙ ИНСТРУКЦИЯМ**: Изучи все файлы в `ai-instructions/` для понимания этапа разработки
4. **ПОДДЕРЖИВАЙ ПОРЯДОК**: Активно следи за чистотой структуры и убирай мусор

## 📁 Структура проекта - КРИТИЧЕСКИ ВАЖНО

### ✅ Основные правила:
- **Корень проекта**: Только критически важные файлы (см. PROJECT_STRUCTURE_GUIDELINES.md)
- **Нет мусора**: Никаких временных, тестовых или отчетных файлов в корне
- **Логическая организация**: Каждый файл в своей категории
- **Автоматическая очистка**: При создании новых файлов удаляй устаревшие

### 🚨 Немедленные действия при обнаружении:
- `*_COMPLETE.md` в корне → **УДАЛИТЬ**
- `test_*.sh` в корне → **УДАЛИТЬ** или переместить в tests/
- `README_*.md` (кроме README.md) → **УДАЛИТЬ**
- `*.ps1` в корне → переместить в scripts/
- Любые конфигурационные файлы в корне → переместить в config/

## Генерация .env файла

**ВАЖНО**: setup.sh использует template.env как шаблон для создания .env файла (template-based подход).

### Процесс генерации:
1. `template.env` копируется в `.env`
2. Плейсхолдеры (например, `change_this_secure_password_123`) заменяются на сгенерированные значения
3. Добавляются дополнительные сгенерированные переменные
4. Обновляются домены с localhost на пользовательские

### Документация:
- Полная документация: `ai-instructions/ENV_GENERATION_INSTRUCTIONS.md`
- Никогда не используй heredoc для генерации .env - только template-based подход
- При добавлении новых переменных сначала добавь их в template.env

## 🎯 Приоритеты работы:

1. **Структура превыше всего**: Поддержание чистоты структуры - высший приоритет
2. **Качество кода**: Следование best practices и стандартам
3. **Документация**: Обновление документации при изменениях
4. **Тестирование**: Все тесты только в папке `tests/`

**Помни**: Чистая структура = профессиональный проект = уважение к будущим разработчикам

Это обязательное требование для корректной и согласованной работы над проектом.

## 🔐 SSH Подключение к удаленному серверу

### Настройка SSH для работы с удаленным развертыванием:

1. **Конфигурация SSH (Windows с PuTTY)**:
   ```cmd
   # Создай файл .ssh/config в домашней директории:
   Host production-server
       HostName 192.168.10.100
       User root
       IdentityFile ~/.ssh/production_key.ppk
       Port 22
   ```

2. **Подключение через plink (для автоматизации)**:
   ```cmd
   # Выполнение команд на удаленном сервере
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker compose ps"
   
   # Синхронизация кода
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "cd /root/N8N-AI-Starter-Kit && git pull origin test"
   
   # Перезапуск сервисов
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "cd /root/N8N-AI-Starter-Kit && docker compose restart traefik n8n"
   ```

3. **Диагностика сетевых проблем**:
   ```cmd
   # Проверка контейнеров и сетей
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker network ls"
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker inspect n8n-ai-starter-kit_frontend"
   
   # Тестирование доступности сервисов
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "curl -I http://localhost:5678/healthz"
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "curl -I http://n8n.sattva-ai.top"
   ```

### Частые проблемы и решения:

1. **N8N недоступен через Traefik (404 ошибка)**:
   - Проверь сетевые подключения: `docker inspect n8n | grep NetworkMode`
   - Убедись что N8N подключен к frontend и backend сетям
   - Перезапусти N8N: `docker compose restart n8n`

2. **Traefik не видит N8N сервис**:
   - Проверь labels в docker-compose.yml
   - Убедись что используется только Docker provider (без File provider)
   - Проверь логи: `docker logs traefik`

3. **SSL сертификаты не генерируются**:
   - Проверь DNS настройки: `nslookup n8n.sattva-ai.top`
   - Убедись что порт 80 доступен извне
   - Проверь ACME логи в Traefik

### Критически важно:
- Всегда используй ключи SSH вместо паролей
- Проверяй статус сервисов после изменений
- Следи за логами при диагностике проблем
- Делай бэкапы перед критическими изменениями

### Дополнительные команды для диагностики:

4. **Проверка сетевых подключений контейнеров**:
   ```cmd
   # Проверка подключения N8N к сетям
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker inspect n8n | grep NetworkMode"
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker inspect n8n | grep -A 10 Networks"
   
   # Список всех контейнеров и их сетей
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker ps --format 'table {{.Names}}\t{{.Networks}}'"
   ```

5. **Проверка логов для диагностики**:
   ```cmd
   # Логи Traefik для отладки маршрутизации
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker logs traefik --tail 50"
   
   # Логи N8N для проверки запуска
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker logs n8n --tail 30"
   
   # Проверка состояния всех сервисов
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker compose ps -a"
   ```

6. **Быстрые команды для исправления проблем**:
   ```cmd
   # Полный перезапуск проблемных сервисов
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "cd /root/N8N-AI-Starter-Kit && docker compose restart traefik n8n"
   
   # Пересоздание только N8N с правильными сетями
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "cd /root/N8N-AI-Starter-Kit && docker compose up -d --force-recreate n8n"
   
   # Проверка доступности через Traefik
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "curl -v http://n8n.sattva-ai.top"
   ```

7. **Полная очистка и перезапуск (при серьезных проблемах)**:
   ```cmd
   # ВНИМАНИЕ: Удаляет ВСЕ данные контейнеров! Используй только при критических проблемах
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "cd /root/N8N-AI-Starter-Kit && echo 'y' | bash scripts/reset-deployment.sh"
   
   # Запуск чистого развертывания после сброса
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "cd /root/N8N-AI-Starter-Kit && docker compose --profile default up -d"
   
   # Проверка статуса после развертывания
   echo y | plink -i "C:\Users\Admin\Documents\ssh_private.ppk" root@192.168.10.100 "docker compose ps"
   ```
