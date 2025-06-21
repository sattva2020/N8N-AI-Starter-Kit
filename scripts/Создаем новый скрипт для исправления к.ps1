# Создаем новый скрипт для исправления конфликтов Docker Compose
$scriptContent = @"
# Скрипт для исправления конфликтов Docker Compose
# Автор: GitHub Copilot
# Дата: $(Get-Date -Format "yyyy-MM-dd")

Write-Host "Начинаем исправление конфликтов Docker Compose..." -ForegroundColor Cyan

# 1. Исправление конфликта с networks
Write-Host "Проверка файла networks.yml..." -ForegroundColor Yellow
if (Test-Path "./compose/networks.yml") {
    $networksContent = Get-Content "./compose/networks.yml" -Raw
    
    # Проверяем, содержит ли файл определение сети frontend
    if ($networksContent -match "frontend:") {
        Write-Host "Найдено определение сети frontend в networks.yml" -ForegroundColor Yellow
        
        # Создаем резервную копию
        Copy-Item "./compose/networks.yml" "./compose/networks.yml.bak"
        
        # Комментируем определение frontend
        $newContent = $networksContent -replace "(\s+frontend:.*?)(driver:\s*bridge)", '$1#driver: bridge'
        Set-Content -Path "./compose/networks.yml" -Value $newContent
        
        Write-Host "Закомментировано определение frontend в networks.yml" -ForegroundColor Green
    }
}

# 2. Исправление версии в ollama-compose.yml
Write-Host "Проверка файла ollama-compose.yml..." -ForegroundColor Yellow
if (Test-Path "./compose/ollama-compose.yml") {
    $ollamaContent = Get-Content "./compose/ollama-compose.yml" -Raw
    
    # Проверяем, содержит ли файл атрибут version
    if ($ollamaContent -match "version:") {
        Write-Host "Найден устаревший атрибут version в ollama-compose.yml" -ForegroundColor Yellow
        
        # Создаем резервную копию
        Copy-Item "./compose/ollama-compose.yml" "./compose/ollama-compose.yml.bak"
        
        # Удаляем атрибут version
        $newContent = $ollamaContent -replace "version:.*?\n", ""
        Set-Content -Path "./compose/ollama-compose.yml" -Value $newContent
        
        Write-Host "Удален атрибут version из ollama-compose.yml" -ForegroundColor Green
    }
}

# 3. Проверка определения сервиса ollama в docker-compose.yml
Write-Host "Проверка файла docker-compose.yml..." -ForegroundColor Yellow
$dockerContent = Get-Content "./docker-compose.yml" -Raw
if ($dockerContent -match "\s+ollama:\s*\n\s+<<") {
    Write-Host "Найдено раскомментированное определение сервиса ollama в docker-compose.yml" -ForegroundColor Yellow
    
    # Создаем резервную копию
    Copy-Item "./docker-compose.yml" "./docker-compose.yml.bak"
    
    # Комментируем определение ollama
    $newContent = $dockerContent -replace "(\s+ollama:\s*\n\s+<<:.*?\n)", '$1#'
    Set-Content -Path "./docker-compose.yml" -Value $newContent
    
    Write-Host "Закомментировано определение ollama в docker-compose.yml" -ForegroundColor Green
}

Write-Host "`nИсправления завершены. Теперь можно запустить Docker Compose:" -ForegroundColor Cyan
Write-Host "docker compose --profile cpu up -d" -ForegroundColor Green
"@

# Сохраняем скрипт в файл
$scriptContent | Out-File -FilePath ".\fix-docker-conflicts.ps1" -Encoding utf8

Write-Host "Скрипт fix-docker-conflicts.ps1 создан. Запустите его для исправления конфликтов."