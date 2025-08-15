# =============================================================================
# N8N AI Starter Kit - Remote Server Management Script (PowerShell)
# =============================================================================
# Скрипт для управления N8N AI Starter Kit на удаленном сервере через SSH
# =============================================================================

param(
  [Parameter(Mandatory = $true)]
  [string]$ServerIP,
    
  [Parameter(Mandatory = $false)]
  [string]$Username = "root",
    
  [Parameter(Mandatory = $false)]
  [string]$Action = "deploy",
    
  [Parameter(Mandatory = $false)]
  [string]$SSHKey = ""
)

# Цвета для вывода
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-Status {
  param([string]$Message)
  Write-Host "${Green}[INFO]${Reset} $Message"
}

function Write-Warning {
  param([string]$Message)
  Write-Host "${Yellow}[WARNING]${Reset} $Message"
}

function Write-Error {
  param([string]$Message)
  Write-Host "${Red}[ERROR]${Reset} $Message"
}

function Test-SSHConnection {
  param([string]$Server, [string]$User)
    
  Write-Status "Testing SSH connection to $User@$Server..."
    
  $sshCommand = "ssh -o ConnectTimeout=10 -o BatchMode=yes $User@$Server exit"
    
  try {
    $result = Invoke-Expression $sshCommand 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Status "SSH connection successful"
      return $true
    }
    else {
      Write-Error "SSH connection failed"
      return $false
    }
  }
  catch {
    Write-Error "SSH connection error: $_"
    return $false
  }
}

function Deploy-Server {
  param([string]$Server, [string]$User)
    
  Write-Status "Deploying N8N AI Starter Kit to $Server..."
    
  $deployScript = @"
curl -fsSL https://raw.githubusercontent.com/sattva2020/N8N-AI-Starter-Kit/main/scripts/deploy-server.sh | bash
"@
    
  $sshCommand = "ssh $User@$Server '$deployScript'"
    
  try {
    Invoke-Expression $sshCommand
    Write-Status "Deployment completed successfully!"
  }
  catch {
    Write-Error "Deployment failed: $_"
  }
}

function Check-ServerStatus {
  param([string]$Server, [string]$User)
    
  Write-Status "Checking server status..."
    
  $statusScript = @"
cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit
if [ -f "scripts/check-server-status.sh" ]; then
    chmod +x scripts/check-server-status.sh
    ./scripts/check-server-status.sh
else
    echo "Status script not found. Checking manually..."
    echo "Docker containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "System resources:"
    free -h
    df -h
fi
"@
    
  $sshCommand = "ssh $User@$Server '$statusScript'"
    
  try {
    Invoke-Expression $sshCommand
  }
  catch {
    Write-Error "Status check failed: $_"
  }
}

function Update-Server {
  param([string]$Server, [string]$User)
    
  Write-Status "Updating server..."
    
  $updateScript = @"
cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit
if [ -f "scripts/update-server.sh" ]; then
    chmod +x scripts/update-server.sh
    ./scripts/update-server.sh
else
    echo "Update script not found. Performing manual update..."
    git pull origin main
    docker-compose pull
    docker-compose down
    docker-compose --profile cpu up -d
fi
"@
    
  $sshCommand = "ssh $User@$Server '$updateScript'"
    
  try {
    Invoke-Expression $sshCommand
    Write-Status "Update completed successfully!"
  }
  catch {
    Write-Error "Update failed: $_"
  }
}

function Stop-Server {
  param([string]$Server, [string]$User)
    
  Write-Status "Stopping N8N services..."
    
  $stopScript = @"
cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit
docker-compose down
"@
    
  $sshCommand = "ssh $User@$Server '$stopScript'"
    
  try {
    Invoke-Expression $sshCommand
    Write-Status "Services stopped successfully!"
  }
  catch {
    Write-Error "Failed to stop services: $_"
  }
}

function Start-Server {
  param([string]$Server, [string]$User)
    
  Write-Status "Starting N8N services..."
    
  $startScript = @"
cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit
docker-compose --profile cpu up -d
"@
    
  $sshCommand = "ssh $User@$Server '$startScript'"
    
  try {
    Invoke-Expression $sshCommand
    Write-Status "Services started successfully!"
        
    Write-Host ""
    Write-Host "${Blue}Access URLs:${Reset}"
    Write-Host "N8N Interface: http://$ServerIP`:5678"
    Write-Host "Web Interface: http://$ServerIP`:8002"
    Write-Host "Document Processor: http://$ServerIP`:8001"
    Write-Host "Qdrant Dashboard: http://$ServerIP`:6333/dashboard"
  }
  catch {
    Write-Error "Failed to start services: $_"
  }
}

function Get-ServerLogs {
  param([string]$Server, [string]$User)
    
  Write-Status "Retrieving server logs..."
    
  $logsScript = @"
cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit
echo "=== Docker Compose Services ==="
docker-compose ps
echo ""
echo "=== Recent Logs (last 50 lines) ==="
docker-compose logs --tail=50
"@
    
  $sshCommand = "ssh $User@$Server '$logsScript'"
    
  try {
    Invoke-Expression $sshCommand
  }
  catch {
    Write-Error "Failed to retrieve logs: $_"
  }
}

function Backup-Server {
  param([string]$Server, [string]$User)
    
  Write-Status "Creating server backup..."
    
  $backupScript = @"
cd /opt/n8n-ai-starter-kit 2>/dev/null || cd ~/N8N-AI-Starter-Kit 2>/dev/null || cd N8N-AI-Starter-Kit

BACKUP_DIR="/tmp/n8n-backup-`$(date +%Y%m%d-%H%M%S)"
mkdir -p "`$BACKUP_DIR"

# Backup environment files
cp -r .env* "`$BACKUP_DIR/" 2>/dev/null || true

# Backup Docker volumes
echo "Backing up Docker volumes..."
docker run --rm -v n8n_storage:/data -v "`$BACKUP_DIR":/backup alpine tar czf /backup/n8n_storage.tar.gz -C /data .

echo "Backup created at: `$BACKUP_DIR"
ls -la "`$BACKUP_DIR"
"@
    
  $sshCommand = "ssh $User@$Server '$backupScript'"
    
  try {
    Invoke-Expression $sshCommand
    Write-Status "Backup completed successfully!"
  }
  catch {
    Write-Error "Backup failed: $_"
  }
}

function Show-Help {
  Write-Host ""
  Write-Host "${Blue}N8N AI Starter Kit - Remote Server Management${Reset}"
  Write-Host ""
  Write-Host "Usage: .\manage-server.ps1 -ServerIP <IP> -Username <user> -Action <action>"
  Write-Host ""
  Write-Host "Parameters:"
  Write-Host "  -ServerIP   : IP address of the remote server (required)"
  Write-Host "  -Username   : SSH username (default: root)"
  Write-Host "  -Action     : Action to perform (default: deploy)"
  Write-Host "  -SSHKey     : Path to SSH private key (optional)"
  Write-Host ""
  Write-Host "Available Actions:"
  Write-Host "  deploy      : Deploy N8N AI Starter Kit to server"
  Write-Host "  status      : Check server and services status"
  Write-Host "  update      : Update server to latest version"
  Write-Host "  start       : Start N8N services"
  Write-Host "  stop        : Stop N8N services"
  Write-Host "  restart     : Restart N8N services"
  Write-Host "  logs        : Show service logs"
  Write-Host "  backup      : Create backup of data"
  Write-Host "  help        : Show this help message"
  Write-Host ""
  Write-Host "Examples:"
  Write-Host "  .\manage-server.ps1 -ServerIP 192.168.1.100 -Action deploy"
  Write-Host "  .\manage-server.ps1 -ServerIP 192.168.1.100 -Username ubuntu -Action status"
  Write-Host "  .\manage-server.ps1 -ServerIP 192.168.1.100 -Action update"
  Write-Host ""
}

# Главная функция
function Main {
  Write-Host ""
  Write-Host "${Blue}============================================${Reset}"
  Write-Host "${Blue}  N8N AI Starter Kit - Server Management   ${Reset}"
  Write-Host "${Blue}============================================${Reset}"
  Write-Host ""
    
  if ($Action -eq "help") {
    Show-Help
    return
  }
    
  # Проверка SSH
  if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Error "SSH client not found. Please install OpenSSH or use WSL."
    return
  }
    
  # Тест подключения
  if (-not (Test-SSHConnection -Server $ServerIP -User $Username)) {
    Write-Error "Cannot connect to server. Please check:"
    Write-Host "  1. Server IP is correct: $ServerIP"
    Write-Host "  2. SSH service is running on server"
    Write-Host "  3. SSH key is properly configured"
    Write-Host "  4. Username is correct: $Username"
    return
  }
    
  # Выполнение действия
  switch ($Action.ToLower()) {
    "deploy" { Deploy-Server -Server $ServerIP -User $Username }
    "status" { Check-ServerStatus -Server $ServerIP -User $Username }
    "update" { Update-Server -Server $ServerIP -User $Username }
    "start" { Start-Server -Server $ServerIP -User $Username }
    "stop" { Stop-Server -Server $ServerIP -User $Username }
    "restart" { 
      Stop-Server -Server $ServerIP -User $Username
      Start-Sleep -Seconds 5
      Start-Server -Server $ServerIP -User $Username
    }
    "logs" { Get-ServerLogs -Server $ServerIP -User $Username }
    "backup" { Backup-Server -Server $ServerIP -User $Username }
    default {
      Write-Error "Unknown action: $Action"
      Show-Help
    }
  }
}

# Запуск
Main
