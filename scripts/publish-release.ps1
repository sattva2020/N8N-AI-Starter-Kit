# 🚀 N8N AI Starter Kit - Скрипт Публикации v1.1.4
# Автоматизированная публикация релиза (PowerShell)

param(
  [string]$Version = "v1.1.4",
  [switch]$Force = $false
)

# Настройка цветов
$Host.UI.RawUI.BackgroundColor = "Black"

function Write-ColorText {
  param(
    [string]$Text,
    [string]$Color = "White"
  )
  Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
  param([string]$Text)
  Write-Host ""
  Write-ColorText "=================================================" "Cyan"
  Write-ColorText $Text "Yellow"
  Write-ColorText "=================================================" "Cyan"
}

function Write-Step {
  param([string]$Text)
  Write-Host ""
  Write-ColorText "📋 $Text" "Yellow"
}

function Write-Success {
  param([string]$Text)
  Write-ColorText "✅ $Text" "Green"
}

function Write-Warning {
  param([string]$Text)
  Write-ColorText "⚠️  $Text" "Yellow"
}

function Write-Error {
  param([string]$Text)
  Write-ColorText "❌ $Text" "Red"
}

function Write-Info {
  param([string]$Text)
  Write-ColorText "ℹ️  $Text" "Cyan"
}

# Заголовок
Clear-Host
Write-Header "🚀 N8N AI Starter Kit - Публикация Релиза $Version"

$releaseTitle = "🚀 N8N AI Starter Kit $Version - Enterprise AI Automation Platform"

# Этап 1: Проверка готовности
Write-Step "ЭТАП 1: Проверка готовности"

Write-Info "Проверяем статус Git..."
$gitStatus = git status --porcelain
if ($gitStatus) {
  Write-Warning "Есть незакоммиченные изменения!"
  git status --short
  if (-not $Force) {
    $continue = Read-Host "Продолжить? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
      exit 1
    }
  }
}

Write-Info "Проверяем временные файлы..."
$tempFiles = Get-ChildItem -Path . -Name "*SUCCESS*.md", "*FINAL*.md", "*REPORT*.md", "*TEST*.md" -ErrorAction SilentlyContinue
if ($tempFiles) {
  Write-Warning "Найдены временные файлы:"
  $tempFiles | ForEach-Object { Write-Host "  $_" }
  if (-not $Force) {
    $remove = Read-Host "Удалить их? (Y/n)"
    if ($remove -eq "" -or $remove -eq "Y" -or $remove -eq "y") {
      $tempFiles | ForEach-Object { Remove-Item $_ -Force }
      Write-Success "Временные файлы удалены"
    }
  }
}

# Этап 2: Финальный коммит
Write-Step "ЭТАП 2: Создание финального коммита"

if (-not $Force) {
  $createCommit = Read-Host "Создать финальный коммит? (Y/n)"
  if ($createCommit -eq "" -or $createCommit -eq "Y" -or $createCommit -eq "y") {
    git add .
    try {
      git commit -m "🚀 RELEASE $Version`: Final cleanup and preparation for publication"
      Write-Success "Финальный коммит создан"
    }
    catch {
      Write-Info "Нет изменений для коммита"
    }
  }
}

# Этап 3: Создание тега
Write-Step "ЭТАП 3: Создание тега релиза"

# Проверяем существует ли тег
$tagExists = git rev-parse $Version 2>$null
if ($tagExists -and -not $Force) {
  Write-Warning "Тег $Version уже существует"
  $recreate = Read-Host "Пересоздать тег? (y/N)"
  if ($recreate -eq "y" -or $recreate -eq "Y") {
    git tag -d $Version
    git push --delete origin $Version 2>$null
    $tagExists = $false
  }
}

if (-not $tagExists -or $Force) {
  Write-Info "Создаем аннотированный тег..."
    
  $tagMessage = @"
Release $Version`: Advanced N8N Workflows & Production Security

🚀 Major Features:
- 6 Advanced N8N Workflows для полной автоматизации
- SSL Production Setup с Let's Encrypt
- Auto-Import система для workflows
- Production Security с enterprise-grade headers
- Comprehensive monitoring & analytics

✨ New Components:
- Document Processing Pipeline
- RAG Query Automation  
- Batch Processing (до 50 файлов)
- Error Handling & Notifications
- System Monitoring
- Email Integration

🔗 API Enhancements:
- 5 новых webhook endpoints
- RESTful API design
- Automated error handling
- Rate limiting готовность

📚 Complete Documentation:
- Production deployment guides
- SSL setup instructions
- API reference with examples
- Troubleshooting guides
"@

  git tag -a $Version -m $tagMessage
  Write-Success "Тег $Version создан"
}

# Этап 4: Push изменений
Write-Step "ЭТАП 4: Публикация в репозиторий"

if (-not $Force) {
  $pushChanges = Read-Host "Push изменения в origin? (Y/n)"
  if ($pushChanges -eq "" -or $pushChanges -eq "Y" -or $pushChanges -eq "y") {
    Write-Info "Push основной ветки..."
    $currentBranch = git branch --show-current
    git push origin $currentBranch
        
    Write-Info "Push тега..."
    git push origin $Version
        
    Write-Success "Изменения опубликованы в репозиторий"
  }
}

# Этап 5: Информация для GitHub Release
Write-Step "ЭТАП 5: Создание GitHub Release"

Write-ColorText "" "White"
Write-ColorText "=================================================" "Cyan"
Write-ColorText "         СЛЕДУЮЩИЕ ШАГИ НА GITHUB" "Yellow"
Write-ColorText "=================================================" "Cyan"

Write-Host "1. Перейдите на: " -NoNewline
Write-ColorText "https://github.com/sattva2020/N8N-AI-Starter-Kit/releases" "Blue"
Write-Host "2. Нажмите 'Create a new release'"
Write-Host "3. Выберите тег: $Version"
Write-Host "4. Заголовок релиза: $releaseTitle"
Write-Host ""
Write-Host "5. Используйте следующий контент для Release Notes:"

Write-ColorText "============ RELEASE NOTES ============" "Green"

$releaseNotes = @"
🚀 **ENTERPRISE-READY AI AUTOMATION PLATFORM**

Это крупное обновление превращает базовый стартовый набор в enterprise-ready AI систему с полной автоматизацией, мониторингом и production-grade безопасностью.

## ✨ КЛЮЧЕВЫЕ НОВОВВЕДЕНИЯ

### 🤖 **6 Advanced N8N Workflows**
- **Document Processing Pipeline** - автоматическая обработка документов
- **RAG Query Automation** - умные поисковые запросы с AI
- **Batch Processing** - массовая обработка до 50 файлов
- **Error Handling & Notifications** - централизованная обработка ошибок
- **System Monitoring** - автоматический мониторинг сервисов
- **Email Integration** - профессиональные уведомления

### 🔐 **Production Security & SSL**
- Let's Encrypt интеграция
- Enterprise-grade security headers
- Multi-domain SSL поддержка
- Network isolation

### 🚀 **Deployment & Automation**
- Auto-Import система для workflows
- Production deployment scripts (Bash/PowerShell)
- Comprehensive health checks
- Monitoring & analytics

### 🔗 **API Enhancements**
- 5 новых webhook endpoints
- RESTful API design
- Rate limiting готовность
- Automated error handling

## 🎯 QUICK START

``````bash
# Клонирование и запуск
git clone https://github.com/sattva2020/N8N-AI-Starter-Kit.git
cd N8N-AI-Starter-Kit
cp template.env .env
docker-compose --profile cpu up -d

# Доступ к сервисам
echo "N8N: http://localhost:5678"
echo "Web Interface: http://localhost:8002"
echo "Document Processor: http://localhost:8001"
``````

## 📋 MIGRATION FROM v1.1.3
- Automatic workflow import при первом запуске
- Обновленная структура конфигурации
- Новые environment variables в template.env

## 📚 DOCUMENTATION
- [📖 Complete Setup Guide](./README.md)
- [🚀 Server Deployment](./docs/SERVER_DEPLOYMENT.md)
- [🔧 Troubleshooting](./TROUBLESHOOTING.md)
- [📝 Changelog](./CHANGELOG.md)
"@

Write-Host $releaseNotes

Write-ColorText "=====================================" "Green"
Write-Host ""
Write-Host "6. Отметьте 'Set as the latest release'"
Write-Host "7. Нажмите 'Publish release'"

# Копировать Release Notes в буфер обмена (если возможно)
try {
  $releaseNotes | Set-Clipboard
  Write-Success "Release Notes скопированы в буфер обмена!"
}
catch {
  Write-Info "Буфер обмена недоступен, скопируйте текст вручную"
}

# Финальная информация
Write-Header "🎉 АВТОМАТИЧЕСКАЯ ЧАСТЬ ПУБЛИКАЦИИ ЗАВЕРШЕНА!"
Write-ColorText "📋 Осталось только создать GitHub Release по инструкции выше" "Cyan"

Write-Step "📊 СТАТИСТИКА:"
$currentBranch = git branch --show-current
$lastCommit = git rev-parse --short HEAD
$tagCreated = git tag -l $Version

Write-Host "- Версия: $Version"
Write-Host "- Ветка: $currentBranch"
Write-Host "- Последний коммит: $lastCommit"
Write-Host "- Тег создан: $tagCreated"

Write-Success "✅ Проект готов к production использованию!"

# Опциональный запуск браузера
if (-not $Force) {
  $openBrowser = Read-Host "Открыть страницу релизов GitHub? (Y/n)"
  if ($openBrowser -eq "" -or $openBrowser -eq "Y" -or $openBrowser -eq "y") {
    Start-Process "https://github.com/sattva2020/N8N-AI-Starter-Kit/releases/new?tag=$Version"
  }
}

Write-Host ""
Write-ColorText "Нажмите любую клавишу для завершения..." "Gray"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
