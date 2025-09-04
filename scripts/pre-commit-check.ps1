# =============================================================================
# PRE-COMMIT CHECK SCRIPT (PowerShell Version)
# =============================================================================
# Автоматическая проверка и очистка перед коммитом для Windows

param(
    [switch]$Auto,
    [switch]$Strict
)

# Цвета для PowerShell
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Cyan = "Cyan"

function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor $Green }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor $Yellow }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor $Red }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor $Blue }
function Write-Header { param($Message) Write-Host $Message -ForegroundColor $Cyan -BackgroundColor Black }

# Счетчики
$script:IssuesFound = 0
$script:FilesToIgnore = 0
$script:FilesToDelete = 0
$script:CriticalFound = $false

Write-Header "============================================================================="
Write-Header "                    PRE-COMMIT CLEANUP & VALIDATION"
Write-Header "============================================================================="
Write-Host "  Проверяем проект на наличие файлов не предназначенных для публикации" -ForegroundColor $Green
Write-Header "============================================================================="
Write-Host ""

# Паттерны файлов только для разработки
$DevOnlyPatterns = @(
    "*_COMPLETE.md",
    "*_TEST*.md",
    "*_DEBUG*.md",
    "*_TRACE*.md",
    "test_*.sh",
    "debug_*.sh",
    "*.tmp",
    "*.temp",
    "*.bak",
    "*TODO*.md",
    "*NOTES*.md",
    "*DRAFT*.md",
    "LOCAL_*.md",
    "MY_*.md",
    "*_local.*",
    "*_temp.*",
    "*_draft.*",
    "*_v*.md",
    "*SUCCESS*.md",
    "*FINAL*.md",
    "*REPORT*.md",
    "*STAGE*.md",
    "*PLAN*.md",
    "*COMPLETION*.md",
    "*ACCOMPLISHED*.md",
    "*RESOLVED*.md",
    "MISSION_*.md",
    "CRITICAL_*.md",
    "*.log",
    "*trace*.log",
    "setup_trace.log",
    "placeholders.log",
    "replacements.txt",
    "copilot-instructions.md",
    "AI_AGENT_GUIDE.md",
    "frontend_analysis_prompt.md",
    "bfg.jar",
    "*.ppk",
    "plink.exe",
    "puttygen.exe",
    "*.yml.bak*",
    "*.yaml.bak*",
    "*.json.bak*",
    "*.md.backup"
)

$DevOnlyDirectories = @(
    "backup/",
    "backups/",
    ".internal/",
    "logs/",
    "tests/",
    "ai-instructions/",
    ".github/instructions/",
    "volumes/",
    "data/",
    "n8n/",
    "qdrant_data/"
)

# Критичные директории: наличие файлов в этих путях блокирует коммит
$CriticalBlockDirectories = @(
    "ai-instructions/"
)

$SensitivePatterns = @(
    ".env",
    ".env.*",
    "*.ppk",
    "*password*",
    "*secret*",
    "*key*.pem",
    "*credentials*"
)

# Исключения для пустых файлов (плейсхолдеры)
$EmptyFileExclusions = @(
    ".gitkeep",
    ".keep",
    ".placeholder"
)

function Test-EmptyFiles {
    Write-Header "🧹 Поиск пустых файлов"

    try {
        $staged = git diff --cached --name-only --diff-filter=ACM 2>$null
        if (-not $staged) { $staged = git diff --name-only --diff-filter=ACM 2>$null }
    }
    catch {
        $staged = @()
    }

    if (-not $staged -or $staged.Count -eq 0) {
        Write-Info "Нет файлов для проверки на пустоту"
        return
    }

    $found = $false
    foreach ($file in $staged) {
        if (-not $file) { continue }
        $base = [System.IO.Path]::GetFileName($file)
        if ($EmptyFileExclusions -contains $base) { continue }
        if (Test-Path $file -PathType Leaf) {
            $len = (Get-Item $file).Length
            if ($len -eq 0) {
                Write-Warning "Пустой файл: $file"
                $script:FilesToDelete++
                $script:IssuesFound++
                $found = $true
            }
        }
    }

    if (-not $found) {
        Write-Success "Пустых файлов не обнаружено"
    } else {
        $dir = ".internal"
        if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null }
        # Заполнить список пустых файлов во всем индексе для удобства
        $empty = git ls-files 2>$null | Where-Object { Test-Path $_ -PathType Leaf -and (Get-Item $_).Length -eq 0 } |
            Where-Object { $EmptyFileExclusions -notcontains ([System.IO.Path]::GetFileName($_)) }
        $empty | Out-File "$dir/empty-files.txt" -Encoding UTF8
        Write-Info "Список пустых файлов (если есть) записан в .internal/empty-files.txt"
    }
}

function Test-DevOnlyFiles {
    Write-Header "🔍 Проверка файлов только для разработки"

    # Получаем список измененных файлов
    try {
        $stagedFiles = git diff --cached --name-only 2>$null
        if (-not $stagedFiles) {
            Write-Warning "Нет файлов в staging area. Проверяем все измененные файлы..."
            $stagedFiles = git diff --name-only 2>$null
            if (-not $stagedFiles) {
                $stagedFiles = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notlike "*\.git\*" } | Select-Object -First 50 | ForEach-Object { $_.Name }
            }
        }
    }
    catch {
        Write-Warning "Ошибка получения списка файлов: $_"
        return
    }

    Write-Host "Проверяемые файлы:"
    $stagedFiles | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    if ($stagedFiles.Count -gt 10) {
        Write-Host "... и еще $($stagedFiles.Count - 10) файлов"
    }
    Write-Host ""

    # Проверка паттернов
    foreach ($pattern in $DevOnlyPatterns) {
        $regex = $pattern -replace '\*', '.*'
        $matches = $stagedFiles | Where-Object { $_ -match $regex }

        if ($matches) {
            Write-Warning "Найдены файлы для разработки (pattern: $pattern):"
            foreach ($file in $matches) {
                if (Test-Path $file) {
                    Write-Host "  📄 $file"
                    $script:FilesToIgnore++
                }
            }
            $script:IssuesFound++
        }
    }

    # Проверка директорий
    foreach ($dir in $DevOnlyDirectories) {
        $matches = $stagedFiles | Where-Object { $_.StartsWith($dir) }

        if ($matches) {
            Write-Warning "Найдены файлы в директории для разработки: $dir"
            foreach ($file in $matches) {
                Write-Host "  📁 $file"
                $script:FilesToIgnore++
            }
            $script:IssuesFound++

            if ($CriticalBlockDirectories -contains $dir) {
                Write-Error "Критично: обнаружены чувствительные материалы ($dir). Коммит будет заблокирован."
                $script:CriticalFound = $true
            }
        }
    }
}

function Test-SensitiveFiles {
    Write-Header "🔐 Проверка чувствительных данных"

    try {
        $stagedFiles = git diff --cached --name-only 2>$null
        if (-not $stagedFiles) {
            $stagedFiles = git diff --name-only 2>$null
        }
    }
    catch {
        return
    }

    foreach ($pattern in $SensitivePatterns) {
        $regex = $pattern -replace '\*', '.*'
        $matches = $stagedFiles | Where-Object { $_ -match $regex }

        if ($matches) {
            Write-Error "КРИТИЧНО: Найдены чувствительные файлы (pattern: $pattern):"
            foreach ($file in $matches) {
                if (Test-Path $file) {
                    Write-Host "  🔒 $file" -ForegroundColor $Red
                    $script:FilesToIgnore++
                }
            }
            $script:IssuesFound++
        }
    }
}

function Update-GitIgnore {
    Write-Header "📝 Обновление .gitignore"

    if (-not (Test-Path ".gitignore")) {
        Write-Warning ".gitignore не найден, создаем..."
        New-Item ".gitignore" -ItemType File | Out-Null
    }

    $importantPatterns = @(
        "*.log",
        "*.tmp",
        "*.temp",
        "*.bak",
        "*_local.*",
        "*_temp.*",
        "*_draft.*",
        "*TODO*.md",
        "*NOTES*.md",
        "*DRAFT*.md",
        "LOCAL_*.md",
        "copilot-instructions.md",
        "ai-instructions/",
        "backup/",
        ".internal/",
        "tests/",
        "*.ppk",
        ".env",
        ".env.*",
        "!.env.example"
    )

    $gitignoreContent = Get-Content ".gitignore" -ErrorAction SilentlyContinue
    $addedPatterns = 0

    foreach ($pattern in $importantPatterns) {
        if ($gitignoreContent -notcontains $pattern) {
            Add-Content ".gitignore" $pattern
            Write-Info "Добавлен паттерн в .gitignore: $pattern"
            $addedPatterns++
        }
    }

    if ($addedPatterns -gt 0) {
        Write-Success "Добавлено $addedPatterns паттернов в .gitignore"
    } else {
        Write-Success ".gitignore актуален"
    }
}

function New-Report {
    Write-Header "📊 Отчет о проверке"

    $reportDir = ".internal"
    if (-not (Test-Path $reportDir)) {
        New-Item $reportDir -ItemType Directory | Out-Null
    }

    $reportFile = "$reportDir/pre-commit-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

    $report = @"
# Pre-Commit Check Report

Дата: $(Get-Date)
Ветка: $(git branch --show-current 2>$null)

## Статистика
- Найдено проблем: $($script:IssuesFound)
- Файлов для игнорирования: $($script:FilesToIgnore)
- Файлов для удаления: $($script:FilesToDelete)

## Рекомендации
$(if ($script:IssuesFound -gt 0) {
    "- Проверьте найденные файлы`n- Добавьте их в .gitignore если нужно`n- Удалите временные файлы"
} else {
    "- Все проверки пройдены успешно"
})

## Проверенные файлы
``````
$(git diff --cached --name-only 2>$null -join "`n")
``````
"@

    $report | Out-File $reportFile -Encoding UTF8
    Write-Info "Отчет сохранен: $reportFile"
}

function Start-InteractiveFix {
    if ($script:IssuesFound -eq 0) {
        Write-Success "Проблем не найдено!"
        return 0
    }

    Write-Header "🛠️ Интерактивное исправление"
    Write-Host "Найдено проблем: $($script:IssuesFound)"
    Write-Host ""
    Write-Host "Выберите действие:"
    Write-Host "1) Показать рекомендации"
    Write-Host "2) Автоматически обновить .gitignore"
    Write-Host "3) Создать список файлов для ручной проверки"
    Write-Host "4) Продолжить без исправлений"
    Write-Host "5) Отменить коммит"

    $choice = Read-Host "Ваш выбор (1-5)"

    switch ($choice) {
        "1" {
            Write-Info "Рекомендации по исправлению:"
            Write-Host "- Добавьте найденные файлы в .gitignore"
            Write-Host "- Удалите временные файлы командой: git clean -fd"
            Write-Host "- Проверьте содержимое файлов на чувствительные данные"
        }
        "2" {
            Update-GitIgnore
            Write-Success "Обновлен .gitignore. Запустите проверку заново."
        }
        "3" {
            Write-Host "Создаем список файлов для проверки..."
            $checkDir = ".internal"
            if (-not (Test-Path $checkDir)) { New-Item $checkDir -ItemType Directory | Out-Null }
            git diff --cached --name-only 2>$null | Out-File "$checkDir/files-to-check.txt" -Encoding UTF8
            git diff --name-only 2>$null | Add-Content "$checkDir/files-to-check.txt"
            Write-Info "Список сохранен в .internal/files-to-check.txt"
        }
        "4" {
            Write-Warning "Продолжаем без исправлений..."
            return 0
        }
        "5" {
            Write-Error "Коммит отменен пользователем"
            exit 1
        }
        default {
            Write-Error "Неверный выбор"
            exit 1
        }
    }
}

# Основная логика
Test-DevOnlyFiles
Test-EmptyFiles
Test-SensitiveFiles
New-Report

if (-not $Auto) {
    Start-InteractiveFix
}

# Финальная проверка
if ($script:CriticalFound) {
    Write-Error "Коммит заблокирован: обнаружены чувствительные файлы (ai-instructions/). Удалите их из индекса."
    exit 1
}
if ($script:IssuesFound -gt 0) {
    Write-Warning "Найдены проблемы. Рекомендуется исправить их перед коммитом."
    if ($Strict) {
        Write-Error "Строгий режим: коммит заблокирован"
        exit 1
    }
} else {
    Write-Success "Все проверки пройдены! Можно делать коммит."
}

Write-Host ""
Write-Info "Для автоматической проверки добавьте в pre-commit hook:"
Write-Info "Запустите: .\scripts\install-pre-commit-hook.ps1"
