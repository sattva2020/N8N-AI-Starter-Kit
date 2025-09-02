<#
PowerShell bootstrap for Windows developers.
- Checks for Python and shellcheck.
- Optionally installs them via winget/choco/scoop when available.
- Non-interactive mode with -Yes flag (auto-accepts prompts).
- Usage: .\scripts\bootstrap-windows.ps1 [-Yes] [-InstallPython] [-InstallShellCheck]
#>
param(
    [switch]$Yes,
    [switch]$InstallPython,
    [switch]$InstallShellCheck
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Err($m){ Write-Host "[ERR] $m" -ForegroundColor Red }

# Detect package managers
$hasWinget = (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
$hasChoco  = (Get-Command choco -ErrorAction SilentlyContinue) -ne $null
$hasScoop  = (Get-Command scoop -ErrorAction SilentlyContinue) -ne $null

Write-Info "Detected managers: winget=$hasWinget, choco=$hasChoco, scoop=$hasScoop"

function Confirm-Or-Abort([string]$msg){
    if ($Yes) { Write-Info "Auto-confirmed: $msg"; return $true }
    $r = Read-Host "$msg [y/N]"
    return $r -match '^[Yy]'
}

function Get-PythonCmd {
    if (Get-Command py -ErrorAction SilentlyContinue) { return "py -3" }
    elseif (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    elseif (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
    else { return $null }
}

# Install Python if missing
$pythonCmd = Get-PythonCmd
if (-not $pythonCmd) {
    if ($InstallPython -or (Confirm-Or-Abort "Python не найден. Установить Python (рекомендуется Python 3.8+)?")) {
        try {
            if ($hasWinget) {
                Write-Info "Устанавливаем Python через winget"
                winget install --id=Python.Python.3 --source=winget --accept-package-agreements --accept-source-agreements | Out-Host
                Write-Ok "winget install python завершен"
            } elseif ($hasChoco) {
                Write-Info "Устанавливаем Python через Chocolatey"
                choco install python -y | Out-Host
                Write-Ok "choco install python завершен"
            } else {
                Write-Warn "Не найден winget/choco. Инструкции по установке: https://www.python.org/downloads/"
            }
        } catch { Write-Err "Ошибка установки Python: $($_.Exception.Message)" }

        # Try refresh PATH and detect again
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
        $pythonCmd = Get-PythonCmd
        if ($pythonCmd) { Write-Ok "Python обнаружен: $pythonCmd" } else { Write-Warn "Python всё ещё не найден" }
    } else { Write-Warn "Пропущена установка Python" }
} else { Write-Ok "Python обнаружен: $pythonCmd" }

# Install PyYAML / requirements
if ($pythonCmd) {
    Write-Info "Настройка pip и установка зависимостей"
    try { iex "$pythonCmd -m pip install --upgrade pip" | Out-Host } catch { Write-Warn "Не удалось обновить pip: $($_.Exception.Message)" }
    if (Test-Path requirements.txt) {
        if ($Yes -or (Confirm-Or-Abort "Установить зависимости из requirements.txt?")) {
            try { iex "$pythonCmd -m pip install -r requirements.txt" | Out-Host; Write-Ok "Установлены зависимости из requirements.txt" } catch { Write-Warn "Не удалось установить зависимости: $($_.Exception.Message)" }
        }
    } else {
        if ($Yes -or (Confirm-Or-Abort "Установить PyYAML (pip install PyYAML)?")) {
            try { iex "$pythonCmd -m pip install PyYAML" | Out-Host; Write-Ok "PyYAML установлен" } catch { Write-Warn "Не удалось установить PyYAML: $($_.Exception.Message)" }
        }
    }
} else { Write-Warn "Python не найден — пропускаем установку PyYAML" }

# Install shellcheck
if (-not (Get-Command shellcheck -ErrorAction SilentlyContinue)) {
    if ($InstallShellCheck -or (Confirm-Or-Abort "shellcheck не найден. Установить shellcheck (рекомендуется для локальной проверки скриптов)?")) {
        try {
            if ($hasScoop) {
                scoop install shellcheck | Out-Host
                Write-Ok "scoop install shellcheck завершен"
            } elseif ($hasChoco) {
                choco install shellcheck -y | Out-Host
                Write-Ok "choco install shellcheck завершен"
            } elseif ($hasWinget) {
                winget install --id=ShellCheck.ShellCheck -s winget --accept-package-agreements --accept-source-agreements | Out-Host
                Write-Ok "winget install shellcheck завершен"
            } else {
                Write-Warn "Не найден менеджер пакетов (scoop/choco/winget). Установите shellcheck вручную"
            }
        } catch { Write-Warn "Ошибка установки shellcheck: $($_.Exception.Message)" }
    } else { Write-Warn "Пропущена установка shellcheck" }
} else { Write-Ok "shellcheck обнаружен" }

Write-Info "Bootstrap завершен. Проверьте версии ниже:"
try { if ($pythonCmd) { iex "$pythonCmd --version" | Out-Host } } catch {}
try { if (Get-Command shellcheck -ErrorAction SilentlyContinue) { shellcheck --version | Out-Host } } catch {}

# Ensure successful exit code despite optional install failures
$global:LASTEXITCODE = 0
exit 0
