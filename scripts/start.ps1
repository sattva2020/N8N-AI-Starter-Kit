#requires -Version 5.1
[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToMsysPath([string]$WindowsPath) {
  if (-not $WindowsPath) { return '' }
  $drive = $WindowsPath.Substring(0,1).ToLowerInvariant()
  $rest = $WindowsPath.Substring(2).Replace('\\','/')
  if ($rest.StartsWith('/')) { $rest = $rest.Substring(1) }
  return "/$drive/$rest"
}

function Escape-BashArg([string]$Arg) {
  if ($null -eq $Arg) { return "''" }
  $sq = "'"
  $dq = '"'
  $repl = $sq + $dq + $sq + $dq + $sq
  $escaped = $Arg -replace "'", $repl
  return $sq + $escaped + $sq
}

function Invoke-WithGitBash([string]$RepoPath, [string]$ArgsLine) {
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
    (Join-Path $env:ProgramFiles 'Git\usr\bin\bash.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'),
    'bash.exe'
  )
  $bash = $candidates | Where-Object { $_ -and (Get-Command $_ -ErrorAction SilentlyContinue) } | Select-Object -First 1
  if (-not $bash) { return $false }

  $msysPath = Convert-ToMsysPath $RepoPath
  $cmd = "cd `"$msysPath`" && ./start.sh $ArgsLine"
  & $bash -lc $cmd
  exit $LASTEXITCODE
}

function Invoke-WithWSL([string]$RepoPath, [string]$ArgsLine) {
  $wsl = Get-Command 'wsl.exe' -ErrorAction SilentlyContinue
  if (-not $wsl) { return $false }

  # Translate path to WSL path using wslpath
  $wslRepo = & $wsl.Source wslpath -a $RepoPath 2>$null
  if (-not $wslRepo) { return $false }

  $cmd = "cd '$wslRepo' && ./start.sh $ArgsLine"
  & $wsl.Source bash -lc $cmd
  exit $LASTEXITCODE
}

try {
  $repoPath = (Get-Location).Path
  $argsLine = ($Args | ForEach-Object { Escape-BashArg $_ }) -join ' '

  if (-not (Invoke-WithGitBash -RepoPath $repoPath -ArgsLine $argsLine)) {
    if (-not (Invoke-WithWSL -RepoPath $repoPath -ArgsLine $argsLine)) {
      Write-Error 'Не найден Git Bash (bash.exe) и WSL (wsl.exe). Установите Git for Windows или WSL для запуска start.sh из PowerShell.'
      exit 1
    }
  }
  return
}
catch {
  Write-Error $_
  exit 1
}
