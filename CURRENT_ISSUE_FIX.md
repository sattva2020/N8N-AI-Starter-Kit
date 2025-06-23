# � Решение текущей проблемы с Git в ubuntu-vm-deploy.sh

## ❌ Ваша ситуация
Скрипт `ubuntu-vm-deploy.sh` пытается выполнить `git pull origin main`, но получает ошибку:
```
fatal: not a git repository (or any of the parent directories): .git
```

## 📋 Причина
Текущая директория `/home/sattva/n8n-ai-starter-kit` не является git репозиторием.

## ✅ РЕШЕНИЕ 1: Использовать quickfix.sh (РЕКОМЕНДУЕТСЯ)

```bash
# Запустите исправление из текущей директории
./scripts/quickfix.sh

# Затем продолжите развертывание
./scripts/ubuntu-vm-deploy.sh
```

## ✅ РЕШЕНИЕ 2: Инициализировать git репозиторий

```bash
# Инициализация git репозитория
git init

# Добавление remote origin
git remote add origin https://github.com/sattva2020/N8N-AI-Starter-Kit.git

# Теперь можно продолжить с ubuntu-vm-deploy.sh
./scripts/ubuntu-vm-deploy.sh
```

## ✅ РЕШЕНИЕ 3: Запустить Docker напрямую (БЫСТРОЕ)

```bash
# Создать .env файл если нет
cp template.env .env 2>/dev/null || echo "template.env не найден"

# Запустить сервисы напрямую
docker compose --profile cpu up -d

# Проверить статус
docker ps
```

## ✅ РЕШЕНИЕ 4: Ответить "N" на обновление

При следующем запуске `ubuntu-vm-deploy.sh` на вопрос:
```
Обновить проект? (y/N):
```
Ответьте **N** и скрипт продолжит без git pull.

```bash
# 1. Убедитесь, что находитесь в правильной директории
cd ~/n8n-ai-starter-kit

# 2. Создайте .env файл если его нет
if [ ! -f .env ]; then
    cp template.env .env
fi

# 3. Создайте необходимые директории
mkdir -p data/n8n-files data/n8n-workflows logs

# 4. Установите права доступа
chmod +x scripts/*.sh
chmod +x start.sh

# 5. Запустите только Docker сервисы
docker compose up -d
```

## 🚀 Проверка развертывания

После успешного запуска проверьте:

```bash
# Статус контейнеров
docker ps

# Доступность N8N
curl -f http://localhost:5678 || echo "N8N ещё не готов"

# Диагностика системы
./scripts/analyze-services.sh
```

## 📱 Доступ к сервисам

После успешного развертывания сервисы будут доступны по адресам:

- **N8N Web UI**: http://YOUR_VM_IP:5678
- **Qdrant Dashboard**: http://YOUR_VM_IP:6333/dashboard  
- **Ollama API**: http://YOUR_VM_IP:11434

Замените `YOUR_VM_IP` на реальный IP адрес вашей VM (можно узнать командой `hostname -I`).

## 🔧 Дополнительная диагностика

Если проблемы продолжаются:

```bash
# Проверка логов Docker
docker logs n8n-ai-starter-kit-n8n-1

# Проверка доступности портов
sudo netstat -tulpn | grep -E ':5678|:6333|:11434'

# Проверка ресурсов системы
docker stats --no-stream
```

## 📞 Поддержка

Если проблема не решается:
1. Проверьте документацию в `docs/TROUBLESHOOTING.md`
2. Запустите диагностику: `./scripts/comprehensive-container-check.sh`
3. Соберите логи: `docker compose logs > deployment.log`
