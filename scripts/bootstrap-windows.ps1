<#
PowerShell bootstrap for Windows developers.
- Checks for Python and shellcheck.
- Optionally installs them via winget/choco/scoop when available.
- Usage: .\scripts\bootstrap-windows.ps1 [-Yes] [-InstallPython] [-InstallShellCheck]
#>
param(
    [switch]$Yes,
    [switch]$InstallPython,
    [switch]$InstallShellCheck
)

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }

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

# Install Python
if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
    if ($InstallPython -or (Confirm-Or-Abort "Python не найден. Установить Python (рекомендуется Python 3.8+)?")) {
        if ($hasWinget) {
            Write-Info "Устанавливаем Python через winget"
            if ($Yes) { winget install --id=Python.Python.3 --source=winget }
            else { winget install --id=Python.Python.3 --source=winget }
            Write-Ok "winget install завершен"
        } elseif ($hasChoco) {
            Write-Info "Устанавливаем Python через Chocolatey"
            choco install python -y
            Write-Ok "choco install python завершен"
        } else {
            Write-Warn "Не найден winget/choco. Инструкции по установке: https://www.python.org/downloads/"
        }
    } else { Write-Warn "Пропущена установка Python" }
} else { Write-Ok "Python обнаружен" }

# Install PyYAML
if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Info "Устанавливаем PyYAML через pip (requirements.txt если есть)"
    if (Test-Path requirements.txt) {
        if ($Yes -or (Confirm-Or-Abort "Установить зависимости из requirements.txt?")) {
            python -m pip install --upgrade pip
            python -m pip install -r requirements.txt
            Write-Ok "pip install -r requirements.txt завершен"
        }
    } else {
        if ($Yes -or (Confirm-Or-Abort "Установить PyYAML (pip install PyYAML)?")) {
            python -m pip install PyYAML
            Write-Ok "PyYAML установлен"
        }
    }
} else { Write-Warn "Python не найден — пропускаем установку PyYAML" }

# Install shellcheck
if (-not (Get-Command shellcheck -ErrorAction SilentlyContinue)) {
    if ($InstallShellCheck -or (Confirm-Or-Abort "shellcheck не найден. Установить shellcheck (рекомендуется для локальной проверки скриптов)?")) {
        if ($hasScoop) {
            scoop install shellcheck
            Write-Ok "scoop install shellcheck завершен"
        } elseif ($hasChoco) {
            choco install shellcheck -y
            Write-Ok "choco install shellcheck завершен"
        } elseif ($hasWinget) {
            winget install --id=ShellCheck.ShellCheck -s winget
            Write-Ok "winget install shellcheck завершен"
        } else {
            Write-Warn "Не найден менеджер пакетов (scoop/choco/winget). Установите shellcheck вручную"
        }
    } else { Write-Warn "Пропущена установка shellcheck" }
} else { Write-Ok "shellcheck обнаружен" }

Write-Info "Bootstrap завершен. Проверьте python --version и shellcheck --version"
