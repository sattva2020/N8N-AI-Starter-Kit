# 🚀 Шпаргалка: Быстрое развертывание на Ubuntu

## ⚡ Одна команда - полная установка

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/n8n-ai-starter-kit/main/scripts/ubuntu-install.sh | bash
```

> ⚠️ **Примечание**: Замените `YOUR_USERNAME` на ваше имя пользователя GitHub

## 📋 Пошаговая установка (рекомендуется)

### 1. Подготовка системы
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Проверка Docker
docker --version
docker compose version
```

### 2. Получение проекта
```bash
# Клонирование
git clone https://github.com/YOUR_USERNAME/n8n-ai-starter-kit.git
cd n8n-ai-starter-kit

# Права доступа
chmod +x scripts/*.sh start.sh
```

### 3. Запуск
```bash
# Автоматическая настройка и запуск
./start.sh

# Или ручная настройка
./scripts/setup.sh  # настройка
./start.sh          # запуск
```

## 🌐 Доступ к сервисам

После запуска откройте в браузере:
- **n8n**: http://localhost:5678
- **Qdrant**: http://localhost:6333  
- **Traefik**: http://localhost:8080

## 🔧 Основные команды

```bash
# Статус сервисов
docker compose ps

# Логи
docker compose logs -f n8n

# Остановка
docker compose down

# Перезапуск
docker compose restart

# Диагностика
./scripts/diagnose.sh

# Мониторинг
./scripts/monitor.sh
```

## 🚨 Решение проблем

### Порты заняты
```bash
sudo netstat -tulpn | grep :5678
sudo systemctl stop apache2  # если мешает
```

### Права доступа
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Нет .env файла
```bash
./scripts/setup.sh  # создаст автоматически
```

### Docker не запускается
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

---

📖 **Полное руководство**: [UBUNTU_DEPLOYMENT.md](./UBUNTU_DEPLOYMENT.md)
