# 🔐 SSL & Production Deployment Guide
## N8N AI Starter Kit v1.2.0 - Полное руководство

**Дата:** 24 июня 2025  
**Версия:** 1.0  
**Статус:** ✅ ГОТОВО К ИСПОЛЬЗОВАНИЮ

---

## 🎯 ОБЗОР

Данное руководство описывает процесс развертывания N8N AI Starter Kit в production режиме с:
- ✅ **Автоматическими SSL сертификатами** Let's Encrypt
- ✅ **Security headers** и защитой
- ✅ **Доменами и поддоменами** 
- ✅ **HTTPS redirect** для всех сервисов
- ✅ **Production-ready** конфигурацией

---

## 📋 ТРЕБОВАНИЯ

### **Сервер:**
- Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- Docker 20.10+ и Docker Compose v2
- Минимум 4GB RAM, 20GB свободного места
- Порты 80 и 443 открыты в firewall

### **Домен:**
- Зарегистрированный домен (например: `yourdomain.com`)
- Доступ к DNS настройкам
- A записи для поддоменов

### **DNS записи (обязательно):**
```
yourdomain.com           A    YOUR_SERVER_IP
n8n.yourdomain.com       A    YOUR_SERVER_IP  
app.yourdomain.com       A    YOUR_SERVER_IP
api.yourdomain.com       A    YOUR_SERVER_IP
vector.yourdomain.com    A    YOUR_SERVER_IP
ai.yourdomain.com        A    YOUR_SERVER_IP
monitor.yourdomain.com   A    YOUR_SERVER_IP
admin.yourdomain.com     A    YOUR_SERVER_IP
```

---

## 🚀 БЫСТРЫЙ СТАРТ

### **1. Подготовка environment файла**

```bash
# Создаем production конфигурацию
cp .env.production.template .env.production

# Редактируем настройки
nano .env.production
```

**Обязательно измените:**
```env
# Ваш реальный домен
DOMAIN_NAME=yourdomain.com

# Email для Let's Encrypt
ACME_EMAIL=admin@yourdomain.com

# Безопасные пароли
POSTGRES_PASSWORD=your_secure_postgres_password
N8N_ENCRYPTION_KEY=your_32_char_encryption_key_here
TRAEFIK_PASSWORD_HASHED=your_htpasswd_hash

# Домены сервисов
N8N_DOMAIN=n8n.yourdomain.com
WEB_INTERFACE_DOMAIN=app.yourdomain.com
DOCUMENT_PROCESSOR_DOMAIN=api.yourdomain.com
```

### **2. Автоматическое развертывание**

**Linux/macOS:**
```bash
# Запуск production с SSL
bash scripts/deploy-production.sh

# Альтернативные команды
bash scripts/deploy-production.sh stop     # Остановка
bash scripts/deploy-production.sh restart  # Перезапуск
bash scripts/deploy-production.sh logs     # Логи
bash scripts/deploy-production.sh status   # Статус
```

**Windows:**
```powershell
# Запуск production с SSL
.\scripts\deploy-production.ps1

# Альтернативные команды
.\scripts\deploy-production.ps1 stop     # Остановка
.\scripts\deploy-production.ps1 restart  # Перезапуск
.\scripts\deploy-production.ps1 logs     # Логи
.\scripts\deploy-production.ps1 status   # Статус
```

### **3. Ручное развертывание**

```bash
# Остановка development версии
docker-compose --profile default down

# Запуск production с SSL
docker-compose --env-file .env.production --profile production up -d

# Проверка статуса
docker-compose --env-file .env.production --profile production ps
```

---

## 🔧 ДЕТАЛЬНАЯ НАСТРОЙКА

### **Генерация паролей**

```bash
# Для PostgreSQL (32+ символов)
openssl rand -base64 32

# Для N8N Encryption Key (32 символа hex)
openssl rand -hex 16

# Для Traefik Basic Auth
htpasswd -nb admin your_password
```

### **Проверка DNS**

```bash
# Проверка DNS записей
nslookup n8n.yourdomain.com
nslookup app.yourdomain.com
dig +short api.yourdomain.com

# Проверка портов
telnet YOUR_SERVER_IP 80
telnet YOUR_SERVER_IP 443
```

### **Firewall настройка**

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

---

## 🌐 АРХИТЕКТУРА СЕРВИСОВ

### **Production Services Map:**

```
📡 Internet
    ↓ HTTPS (443) / HTTP (80)
🔒 Traefik Proxy (SSL Termination)
    ├── n8n.yourdomain.com        → N8N (port 5678)
    ├── app.yourdomain.com        → Web Interface (port 8002)  
    ├── api.yourdomain.com        → Document Processor (port 8001)
    ├── monitor.yourdomain.com    → Traefik Dashboard
    └── admin.yourdomain.com      → PgAdmin
         ↓ Internal Networks
🔗 Backend Services
    ├── PostgreSQL (5432)
    ├── Qdrant Vector DB (6333)
    ├── Ollama LLM (11434)
    └── Neo4j Graphiti (7687)
```

### **SSL & Security Features:**
- 🔐 **Let's Encrypt** автоматические сертификаты
- 🔒 **TLS 1.2+** minimum version
- 🛡️ **Security Headers** (CSP, HSTS, XSS Protection)
- 🚫 **HTTP → HTTPS** автоматические редиректы
- 🔑 **Basic Auth** для admin панелей
- 💾 **Rate Limiting** защита от DDoS
- 🗜️ **Gzip Compression** для производительности

---

## 🔍 ПРОВЕРКА И ВАЛИДАЦИЯ

### **Проверка SSL сертификатов:**

```bash
# Проверка SSL
curl -I https://n8n.yourdomain.com
curl -I https://app.yourdomain.com
curl -I https://api.yourdomain.com

# Проверка автоперенаправления HTTP → HTTPS
curl -I http://n8n.yourdomain.com
# Должен вернуть: 301 Moved Permanently
```

### **Проверка сервисов:**

```bash
# Health checks
curl https://n8n.yourdomain.com/healthz
curl https://app.yourdomain.com/health
curl https://api.yourdomain.com/health

# SSL Grade проверка
ssl-checker n8n.yourdomain.com
```

### **Мониторинг логов:**

```bash
# Все production логи
docker-compose --env-file .env.production logs -f

# Конкретные сервисы
docker-compose --env-file .env.production logs -f n8n-production
docker-compose --env-file .env.production logs -f traefik-production

# Logи Let's Encrypt
docker-compose --env-file .env.production logs traefik-production | grep acme
```

---

## 🛠️ TROUBLESHOOTING

### **Проблема: SSL сертификаты не получены**

```bash
# Проверка Let's Encrypt логов
docker-compose --env-file .env.production logs traefik-production | grep -i acme

# Общие причины:
# 1. DNS записи не настроены или не распространились
# 2. Порты 80/443 заблокированы firewall
# 3. Неправильный email в ACME_EMAIL
# 4. Превышен rate limit Let's Encrypt (5 попыток/час)

# Решение: проверить DNS, firewall, перезапустить через час
```

### **Проблема: Сервисы недоступны**

```bash
# Проверка статуса контейнеров
docker-compose --env-file .env.production ps

# Проверка health checks
docker-compose --env-file .env.production exec n8n-production curl localhost:5678/healthz

# Перезапуск проблемного сервиса
docker-compose --env-file .env.production restart n8n-production
```

### **Проблема: Performance issues**

```bash
# Мониторинг ресурсов
docker stats

# Увеличение limits в docker-compose.yml
# memory: 4G (вместо 2G)
# cpus: '4' (вместо '2')
```

---

## 📊 MONITORING & MAINTENANCE

### **Доступные Dashboards:**

- **Traefik Dashboard:** `https://monitor.yourdomain.com`
  - SSL статус сертификатов
  - Routing конфигурация
  - Метрики трафика
  - Health checks статус

- **PgAdmin:** `https://admin.yourdomain.com`
  - Database мониторинг
  - Query performance
  - Backup management

### **Регулярное обслуживание:**

```bash
# Обновление образов (раз в месяц)
docker-compose --env-file .env.production pull
docker-compose --env-file .env.production up -d

# Очистка неиспользуемых образов
docker system prune -f

# Backup базы данных
docker-compose --env-file .env.production exec postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d).sql
```

### **SSL сертификаты:**
- Let's Encrypt сертификаты автоматически обновляются каждые 60 дней
- Мониторинг expiration в Traefik Dashboard
- Backup сертификатов в volume `traefik_letsencrypt`

---

## 🔮 ДАЛЬНЕЙШИЕ УЛУЧШЕНИЯ

После успешного развертывания SSL, можно добавить:

1. **Мониторинг:** Prometheus + Grafana
2. **Logs:** Centralized logging (ELK Stack)
3. **Backup:** Автоматические backup workflows
4. **CI/CD:** GitHub Actions для автоматического deployment
5. **Multi-region:** Распределенное развертывание

---

## 📞 ПОДДЕРЖКА

### **Полезные команды:**

```bash
# Статус всех сервисов
docker-compose --env-file .env.production ps

# Логи в реальном времени
docker-compose --env-file .env.production logs -f

# Перезапуск всего стека
docker-compose --env-file .env.production restart

# Остановка с сохранением данных
docker-compose --env-file .env.production stop

# Полная остановка с удалением контейнеров
docker-compose --env-file .env.production down
```

### **Контакты и ресурсы:**
- 📚 **Документация:** [README.md](README.md)
- 🔧 **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- 🐛 **Issues:** GitHub Issues
- 💬 **Community:** N8N Community Forum

---

**🎉 Поздравляем! Ваш N8N AI Starter Kit готов к production использованию с SSL!**

**N8N AI Starter Kit SSL Guide v1.2.0**  
**Status:** ✅ PRODUCTION READY  
**Date:** 24 июня 2025
