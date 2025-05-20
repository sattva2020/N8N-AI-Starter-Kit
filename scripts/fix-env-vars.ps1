# filepath: scripts/fix-env-vars.ps1
# Script to fix missing environment variables for Supabase in PowerShell

Write-Host "Исправление переменных окружения для Supabase..." -ForegroundColor Yellow

# Проверяем и исправляем переменные окружения в .env файле
if (Test-Path ".env") {
  $content = Get-Content ".env" -Raw
  $modified = $false
    
  # Добавляем ANON_KEY из SUPABASE_ANON_KEY если нужно
  if ($content -match "SUPABASE_ANON_KEY=(.+)(?:\r?\n|$)" -and (-not ($content -match "^ANON_KEY="))) {
    $anonValue = $Matches[1]
    Add-Content ".env" "ANON_KEY=$anonValue"
    Write-Host "✅ Добавлена переменная ANON_KEY на основе SUPABASE_ANON_KEY" -ForegroundColor Green
    $modified = $true
  }

  # Добавляем SERVICE_ROLE_KEY из SUPABASE_SERVICE_ROLE_KEY если нужно
  if ($content -match "SUPABASE_SERVICE_ROLE_KEY=(.+)(?:\r?\n|$)" -and (-not ($content -match "^SERVICE_ROLE_KEY="))) {
    $serviceKeyValue = $Matches[1]
    Add-Content ".env" "SERVICE_ROLE_KEY=$serviceKeyValue"
    Write-Host "✅ Добавлена переменная SERVICE_ROLE_KEY на основе SUPABASE_SERVICE_ROLE_KEY" -ForegroundColor Green
    $modified = $true
  }
    
  # Добавляем JWT_SECRET из SUPABASE_JWT_SECRET если нужно
  if ($content -match "SUPABASE_JWT_SECRET=(.+)(?:\r?\n|$)" -and (-not ($content -match "^JWT_SECRET="))) {
    $jwtSecretValue = $Matches[1]
    Add-Content ".env" "JWT_SECRET=$jwtSecretValue"
    Write-Host "✅ Добавлена переменная JWT_SECRET на основе SUPABASE_JWT_SECRET" -ForegroundColor Green
    $modified = $true
  }
    
  if ($modified) {
    Write-Host "Переменные окружения успешно исправлены!" -ForegroundColor Green
  }
  else {
    Write-Host "Все необходимые переменные окружения уже определены." -ForegroundColor Green
  }
}
else {
  Write-Host "❌ Файл .env не найден. Сначала запустите скрипт setup.sh для создания файла .env." -ForegroundColor Red
  exit 1
}
