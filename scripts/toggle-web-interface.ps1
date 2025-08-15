# Toggle web-interface service in docker-compose.yml by commenting or uncommenting its block.
# Usage:
#   .\scripts\toggle-web-interface.ps1 -Action disable
#   .\scripts\toggle-web-interface.ps1 -Action enable

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('enable', 'disable')]
  [string]$Action
)

$file = Join-Path $PSScriptRoot '..\docker-compose.yml' | Resolve-Path -Relative
$filePath = (Resolve-Path $file).Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$bak = "$filePath.bak.$timestamp"
Copy-Item -Path $filePath -Destination $bak -Force

Write-Host "Backup saved to: $bak"

$lines = Get-Content -LiteralPath $filePath -ErrorAction Stop -Encoding UTF8

# Find start of block: line that begins with two spaces then 'web-interface:'
$startIdx = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^[ \t]{2}web-interface:') { $startIdx = $i; break }
}
if ($null -eq $startIdx) { Write-Host "web-interface block not found in $filePath"; exit 1 }

# Find end of block: next line after start that begins with two spaces and non-space then ':' (next service)
$endIdx = $lines.Count
for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^[ \t]{2}\S.+:') { $endIdx = $i; break }
}

# Decide action
if ($Action -eq 'disable') {
  for ($i = $startIdx; $i -lt $endIdx; $i++) {
    if ($lines[$i] -notmatch '^[ \t]*#') { $lines[$i] = '# ' + $lines[$i] }
  }
  Set-Content -LiteralPath $filePath -Value ($lines -join "`n") -Encoding UTF8
  Write-Host "web-interface has been disabled (commented)."
}
else {
  for ($i = $startIdx; $i -lt $endIdx; $i++) {
    $lines[$i] = $lines[$i] -replace '^[ \t]*#\s?', ''
  }
  Set-Content -LiteralPath $filePath -Value ($lines -join "`n") -Encoding UTF8
  Write-Host "web-interface has been enabled (uncommented)."
}
