# Генерируем случайные пароли
$postgres_pwd = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach { [char]$_ })
$n8n_key = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach { [char]$_ })
$jwt_secret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach { [char]$_ })
$pgadmin_pwd = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 16 | ForEach { [char]$_ })

# Читаем файл и заменяем
$content = Get-Content .env -Raw
$content = $content -replace 'change_this_secure_password_123', $postgres_pwd
$content = $content -replace 'your_32_char_encryption_key_here_', $n8n_key  
$content = $content -replace 'your_jwt_secret_key_here_min_32_chars', $jwt_secret
$content = $content -replace 'pgadmin_secure_password_123', $pgadmin_pwd

# Сохраняем
$content | Set-Content .env

Write-Host "Пароли сгенерированы и заменены в .env:"
Write-Host "PostgreSQL: $postgres_pwd"
Write-Host "N8N Encryption: $n8n_key"
Write-Host "JWT Secret: $jwt_secret"
Write-Host "PgAdmin: $pgadmin_pwd"
