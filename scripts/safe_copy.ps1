<#
PowerShell safe copy script.
Usage: .\safe_copy.ps1 -LocalPath <path> -RemoteSpec <user@host:path> [-Force]
#>
param(
  [Parameter(Mandatory=$true)] [string]$LocalPath,
  [Parameter(Mandatory=$true)] [string]$RemoteSpec,
  <#
  PowerShell safe copy script.
  Usage: .\safe_copy.ps1 -LocalPath <path> -RemoteSpec <user@host:/path/to/file> [-Force] [-Identity <private_key_path>]

  This script:
   - computes SHA256 for local and remote files
   - shows a diff when remote exists
   - creates a remote backup before overwrite (.bak.<epoch>)
   - requires -Force to actually overwrite
   - supports -Identity to pass a private ssh key to ssh/scp (mapped to -i)
  #>

  param(
    [Parameter(Mandatory=$true)] [string]$LocalPath,
    [Parameter(Mandatory=$true)] [string]$RemoteSpec,
    [switch]$Force,
    [string]$Identity
  )

  if (-not (Test-Path $LocalPath -PathType Leaf)) { Write-Error "Local file not found: $LocalPath"; exit 2 }

  try {
    $LocalHash = (Get-FileHash -Algorithm SHA256 -Path $LocalPath).Hash
  } catch {
    Write-Error "Failed to compute local hash: $_"; exit 2
  }

  Write-Host "Local sha256: $LocalHash"

  $parts = $RemoteSpec -split ":",2
  if ($parts.Length -ne 2) { Write-Error "RemoteSpec must be in form user@host:/path/to/file"; exit 2 }
  $remote = $parts[0]
  $remotePath = $parts[1]

  # prepare ssh/scp args (add -i when Identity provided)
  $sshArgs = @()
  if ($PSBoundParameters.ContainsKey('Identity') -and $Identity) { $sshArgs += '-i'; $sshArgs += $Identity }

  # helper: run ssh with optional args
  function Run-SshCmd($cmd) {
    if ($sshArgs.Count -gt 0) { return & ssh @($sshArgs + $remote) $cmd }
    return & ssh $remote $cmd
  }

  # check remote existence
  $existsOut = if ($sshArgs.Count -gt 0) { & ssh @($sshArgs + $remote) "test -f '$remotePath' && echo exists" 2>$null } else { & ssh $remote "test -f '$remotePath' && echo exists" 2>$null }
  $exists = $existsOut -and ($existsOut -match 'exists')

  if ($exists) {
    $shaCmd = "sha256sum '$remotePath' 2>/dev/null || python3 -c \"import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())\" '$remotePath'"
    $remoteHashOut = if ($sshArgs.Count -gt 0) { & ssh @($sshArgs + $remote) $shaCmd 2>$null } else { & ssh $remote $shaCmd 2>$null }
    $remoteHash = ($remoteHashOut -split '\s+')[0]
    Write-Host "Remote sha256: $remoteHash"
    if ($remoteHash -eq $LocalHash) { Write-Host "Files identical; nothing to do"; exit 0 }

    Write-Host "--- diff (remote -> local) ---"
    $tmp = Join-Path $env:TEMP "_remote.tmp"
    if ($sshArgs.Count -gt 0) { & ssh @($sshArgs + $remote) "cat '$remotePath'" > $tmp } else { & ssh $remote "cat '$remotePath'" > $tmp }
    if (Get-Command fc -ErrorAction SilentlyContinue) { & fc $tmp $LocalPath } else { Compare-Object -ReferenceObject (Get-Content $tmp) -DifferenceObject (Get-Content $LocalPath) | Out-Host }
    Remove-Item $tmp -ErrorAction SilentlyContinue
  } else {
    Write-Host "Remote file does not exist: $remote:$remotePath"
  }

  if (-not $Force) { Write-Host "To overwrite remote file re-run with -Force"; exit 3 }

  $ts = [int][double]::Parse((Get-Date -UFormat %s))
  $bak = "$remotePath.bak.$ts"
  if ($sshArgs.Count -gt 0) { & ssh @($sshArgs + $remote) "mkdir -p \"$(dirname '$remotePath')\" && cp -a '$remotePath' '$bak' 2>/dev/null || true" } else { & ssh $remote "mkdir -p \"$(dirname '$remotePath')\" && cp -a '$remotePath' '$bak' 2>/dev/null || true" }
  Write-Host "Remote backup created (if existed): $remote:$bak"

  # perform copy
  if ($sshArgs.Count -gt 0) { scp @($sshArgs + $LocalPath + $RemoteSpec) } else { scp $LocalPath $RemoteSpec }

  # verify
  $verifyOut = if ($sshArgs.Count -gt 0) { & ssh @($sshArgs + $remote) $shaCmd 2>$null } else { & ssh $remote $shaCmd 2>$null }
  $verifyHash = ($verifyOut -split '\s+')[0]
  if ($verifyHash -eq $LocalHash) { Write-Host "Copy verified: checksums match"; exit 0 } else { Write-Error "Verification failed: remote checksum differs"; exit 4 }
