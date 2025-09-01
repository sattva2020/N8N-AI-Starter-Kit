# N8N AI Starter Kit - Production Deployment Script (PowerShell)
# Автоматизация запуска production конфигурации с SSL для Windows

param(
  [Parameter(Position = 0)]
  [ValidateSet("deploy", "stop", "restart", "logs", "status")]
  [string]$Action = "deploy"
)

# Функции логирования
function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
  param([string]$Message)
  Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
  param([string]$Message)
  Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Проверка существования .env.production
function Test-ProductionEnv {
  if (-not (Test-Path ".env.production")) {
    Write-Warn ".env.production не найден!"
    Write-Info "Создаю из шаблона .env.production.template..."
        
    if (Test-Path ".env.production.template") {
      Copy-Item ".env.production.template" ".env.production"
      Write-Warn "⚠️  ВАЖНО: Настройте .env.production перед запуском!"
      Write-Info "Измените следующие значения:"
      Write-Host "  - DOMAIN_NAME=yourdomain.com"
      Write-Host "  - ACME_EMAIL=admin@yourdomain.com"  
      Write-Host "  - Все пароли CHANGE_THIS_*"
      Write-Host ""
      Read-Host "Нажмите Enter когда настроите .env.production"
    }
    else {
      Write-Error "Файл .env.production.template не найден!"
      exit 1
    }
  }
}

# Проверка DNS и доменов
function Test-DNS {
  Write-Info "Проверка DNS настроек..."
    
  $envVars = @{}
  Get-Content ".env.production" | ForEach-Object {
    if ($_ -match "^([^#][^=]+)=(.*)$") {
      $envVars[$matches[1]] = $matches[2]
    }
  }
    
  if ($envVars["DOMAIN_NAME"] -eq "yourdomain.com") {
    Write-Error "Настройте реальный домен в .env.production"
    exit 1
  }
    
  Write-Info "Домен: $($envVars['DOMAIN_NAME'])"
  Write-Info "N8N: $($envVars['N8N_DOMAIN'])"
  Write-Info "Web Interface: $($envVars['WEB_INTERFACE_DOMAIN'])"
  Write-Info "API: $($envVars['DOCUMENT_PROCESSOR_DOMAIN'])"
}

# Проверка портов
function Test-Ports {
  Write-Info "Проверка доступности портов 80 и 443..."
    
  $port80 = Get-NetTCPConnection -LocalPort 80 -ErrorAction SilentlyContinue
  $port443 = Get-NetTCPConnection -LocalPort 443 -ErrorAction SilentlyContinue
    
  if ($port80) {
    Write-Warn "Порт 80 уже используется"
  }
    
  if ($port443) {
    Write-Warn "Порт 443 уже используется"
  }
}

# Создание директорий
function New-Directories {
  Write-Info "Создание необходимых директорий..."
    
  $directories = @(
    ".\data\uploads",
    ".\data\processed", 
    ".\config\traefik\dynamic"
  )
    
  foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
  }
}

# Остановка development сервисов
function Stop-Development {
  Write-Info "Остановка development сервисов..."
  docker-compose --profile default --profile cpu --profile developer down
}

# Запуск production сервисов
function Start-Production {
  Write-Info "Запуск production сервисов с SSL..."
    
  # Используем production environment
  docker-compose --env-file .env.production --profile production up -d
    
  Write-Info "Ожидание готовности сервисов..."
  Start-Sleep 30
    
  # Проверка здоровья сервисов
  docker-compose --env-file .env.production --profile production ps
}

# Проверка SSL сертификатов
function Test-SSL {
  Write-Info "Проверка SSL сертификатов..."
    
  $envVars = @{}
  Get-Content ".env.production" | ForEach-Object {
    if ($_ -match "^([^#][^=]+)=(.*)$") {
      $envVars[$matches[1]] = $matches[2]
    }
  }
    
  # Проверяем доступность сервисов
  $domains = @($envVars["N8N_DOMAIN"], $envVars["WEB_INTERFACE_DOMAIN"], $envVars["DOCUMENT_PROCESSOR_DOMAIN"])
    
  foreach ($domain in $domains) {
    Write-Info "Проверка $domain..."
    try {
      $response = Invoke-WebRequest -Uri "https://$domain/health" -UseBasicParsing -TimeoutSec 10
      if ($response.StatusCode -eq 200) {
        Write-Success "✅ $domain доступен через HTTPS"
      }
      else {
        Write-Warn "⚠️  $domain пока недоступен (статус: $($response.StatusCode))"
      }
    }
    catch {
      Write-Warn "⚠️  $domain пока недоступен"
    }
  }
}

# Показать информацию о развертывании
function Show-DeploymentInfo {
  Write-Success "🎉 Production развертывание завершено!"
  Write-Host ""
  Write-Host "📋 Информация о сервисах:"
    
  $envVars = @{}
  Get-Content ".env.production" | ForEach-Object {
    if ($_ -match "^([^#][^=]+)=(.*)$") {
      $envVars[$matches[1]] = $matches[2]
    }
  }
    
  Write-Host "├── 🤖 N8N Workflow Automation: https://$($envVars['N8N_DOMAIN'])"
  Write-Host "├── 🌐 Web Interface: https://$($envVars['WEB_INTERFACE_DOMAIN'])"  
  Write-Host "├── 🔌 Document Processor API: https://$($envVars['DOCUMENT_PROCESSOR_DOMAIN'])"
  Write-Host "├── 📊 Traefik Dashboard: https://$($envVars['TRAEFIK_DASHBOARD_DOMAIN'])"
  Write-Host "└── 🗄️  Database Admin: https://$($envVars['PGADMIN_DOMAIN'])"
  Write-Host ""
  Write-Host "🔐 SSL сертификаты: Let's Encrypt (автоматическое обновление)"
  Write-Host "🔒 Security headers: Включены"
  Write-Host "📈 Мониторинг: Доступен в Traefik Dashboard"
  Write-Host ""
  Write-Info "Логи сервисов: docker-compose --env-file .env.production logs -f"
}

# Главная функция развертывания
function Invoke-Deploy {
  Write-Host ""
  Write-Info "Начинаю production развертывание..."
    
  Test-ProductionEnv
  Test-DNS
  Test-Ports
  New-Directories
  Stop-Development
  Start-Production
    
  Write-Info "Ожидание SSL сертификатов (может занять несколько минут)..."
  Start-Sleep 60
    
  Test-SSL
  Show-DeploymentInfo
}

# Главный блок выполнения
Write-Host "🚀 N8N AI Starter Kit - Production Deployment" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

switch ($Action) {
  "deploy" {
    Invoke-Deploy
  }
  "stop" {
    Write-Info "Остановка production сервисов..."
    docker-compose --env-file .env.production --profile production down
    Write-Success "Production сервисы остановлены"
  }
  "restart" {
    Write-Info "Перезапуск production сервисов..."
    docker-compose --env-file .env.production --profile production restart
  }
  "logs" {
    docker-compose --env-file .env.production --profile production logs -f
  }
  "status" {
    docker-compose --env-file .env.production --profile production ps
  }
  default {
    Write-Host "Использование: .\deploy-production.ps1 [deploy|stop|restart|logs|status]"
    Write-Host ""
    Write-Host "Команды:"
    Write-Host "  deploy   - Развернуть production с SSL (по умолчанию)"
    Write-Host "  stop     - Остановить production сервисы"
    Write-Host "  restart  - Перезапустить production сервисы" 
    Write-Host "  logs     - Показать логи production сервисов"
    Write-Host "  status   - Показать статус production сервисов"
  }
}
