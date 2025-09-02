# =============================================================================
# INSTALL PRE-COMMIT CLEANUP HOOK (PowerShell Version)
# =============================================================================
# Установка автоматической проверки перед коммитом для Windows

# Цвета
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor $Green }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor $Blue }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor $Yellow }

Write-Host "🛠️ Установка pre-commit cleanup hook..." -ForegroundColor $Blue

$projectRoot = Split-Path -Parent $PSScriptRoot
$preCommitPath = Join-Path $projectRoot ".git\hooks\pre-commit"

# Создаем резервную копию
if (Test-Path $preCommitPath) {
    Copy-Item $preCommitPath "$preCommitPath.backup"
    Write-Info "Создана резервная копия: .git\hooks\pre-commit.backup"
}

# Создаем новый pre-commit hook
$hookContent = @'
#!/bin/bash
# =============================================================================
# COMBINED PRE-COMMIT HOOK
# =============================================================================
# Сначала запускаем проверку на мусорные файлы
# Затем запускаем стандартные pre-commit проверки

echo "🔍 Запуск pre-commit cleanup проверки..."

# Определяем ОС и выбираем соответствующий скрипт
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows/Git Bash
    if [[ -f "./scripts/pre-commit-check.ps1" ]]; then
        powershell.exe -ExecutionPolicy Bypass -File "./scripts/pre-commit-check.ps1" -Auto
        cleanup_exit_code=$?
    else
        echo "⚠️ PowerShell скрипт cleanup не найден"
        cleanup_exit_code=0
    fi
else
    # Linux/macOS
    if [[ -f "./scripts/pre-commit-check.sh" ]]; then
        ./scripts/pre-commit-check.sh --auto
        cleanup_exit_code=$?
    else
        echo "⚠️ Bash скрипт cleanup не найден"
        cleanup_exit_code=0
    fi
fi

if [[ $cleanup_exit_code -ne 0 ]]; then
    echo ""
    echo "❌ Cleanup проверка не пройдена!"
    echo "   Запустите соответствующий скрипт для исправления:"
    echo "   Windows: .\scripts\pre-commit-check.ps1"
    echo "   Linux:   ./scripts/pre-commit-check.sh"
    echo "   Или используйте: git commit --no-verify для принудительного коммита"
    exit 1
fi

echo "✅ Cleanup проверка пройдена!"

# Запуск стандартного pre-commit (если есть резервная копия)
if [[ -f ".git/hooks/pre-commit.backup" ]]; then
    echo "🔧 Запуск стандартных pre-commit проверок..."
    .git/hooks/pre-commit.backup "$@"
    standard_exit_code=$?

    if [[ $standard_exit_code -ne 0 ]]; then
        echo "❌ Стандартные pre-commit проверки не пройдены!"
        exit $standard_exit_code
    fi

    echo "✅ Стандартные проверки пройдены!"
fi

echo "🎉 Все pre-commit проверки успешно завершены!"
exit 0
'@

# Записываем hook
$hookContent | Out-File $preCommitPath -Encoding ASCII

Write-Success "Pre-commit hook установлен!"
Write-Info "Теперь при каждом коммите будет автоматически проверяться:"
Write-Host "  • Файлы только для разработки" -ForegroundColor White
Write-Host "  • Чувствительные данные" -ForegroundColor White
Write-Host "  • Содержимое файлов" -ForegroundColor White
Write-Host "  • Обновление .gitignore" -ForegroundColor White

Write-Host ""
Write-Info "Для тестирования запустите:"
Write-Host "  .\scripts\pre-commit-check.ps1" -ForegroundColor White

Write-Host ""
Write-Info "Для отключения hook временно используйте:"
Write-Host "  git commit --no-verify" -ForegroundColor White
