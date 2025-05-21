# PowerShell script to start n8n-ai-starter-kit with the specified profile
# Usage: .\scripts\start.ps1 [cpu|gpu-nvidia|gpu-amd|developer]

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("cpu", "gpu-nvidia", "gpu-amd", "developer")]
    [string]$Profile
)

# Function to display colored console messages
function Write-ColoredOutput {
    param (
        [string]$message,
        [string]$color = "White"
    )
    Write-Host $message -ForegroundColor $color
}

# Check if docker and docker-compose are installed
try {
    $null = docker --version
    Write-ColoredOutput "Docker is installed." "Green"
} catch {
    Write-ColoredOutput "Error: docker is not installed. Please install Docker first." "Red"
    exit 1
}

try {
    $null = docker-compose --version
    $dockerComposeCmd = "docker-compose"
    Write-ColoredOutput "Docker Compose is installed." "Green"
} catch {
    try {
        $null = docker compose version
        $dockerComposeCmd = "docker compose"
        Write-ColoredOutput "Docker Compose plugin is installed." "Green"
    } catch {
        Write-ColoredOutput "Error: docker-compose is not installed. Please install Docker Compose first." "Red"
        exit 1
    }
}

# First run the fix-env-vars script to ensure environment is properly set up
Write-ColoredOutput "Checking and fixing environment variables..." "Yellow"
if (Test-Path "./scripts/fix-env-vars.ps1") {
    & powershell -ExecutionPolicy Bypass -File "./scripts/fix-env-vars.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Error fixing environment variables. Continuing without fixes..." "Red"
    }
} else {
    Write-ColoredOutput "Warning: fix-env-vars.ps1 not found. Continuing without fixing environment variables." "Yellow"
}

# Stop any existing containers first
Write-ColoredOutput "Stopping any existing containers..." "Cyan"
if ($dockerComposeCmd -eq "docker-compose") {
    & docker-compose down
} else {
    & docker compose down
}

# Start with selected profile
Write-ColoredOutput "Starting N8N AI Starter Kit with $Profile profile..." "Cyan"

switch ($Profile) {
    "cpu" {
        Write-ColoredOutput "Using CPU profile for AI services" "Cyan"
        if ($dockerComposeCmd -eq "docker-compose") {
            & docker-compose --profile cpu up -d
            $success = $?
        } else {
            & docker compose --profile cpu up -d
            $success = $?
        }
    }
    "gpu-nvidia" {
        Write-ColoredOutput "Using NVIDIA GPU profile for AI services" "Cyan"
        if ($dockerComposeCmd -eq "docker-compose") {
            & docker-compose --profile gpu-nvidia up -d
            $success = $?
        } else {
            & docker compose --profile gpu-nvidia up -d
            $success = $?
        }
    }
    "gpu-amd" {
        Write-ColoredOutput "Using AMD GPU profile for AI services" "Cyan"
        if ($dockerComposeCmd -eq "docker-compose") {
            & docker-compose --profile gpu-amd up -d
            $success = $?
        } else {
            & docker compose --profile gpu-amd up -d
            $success = $?
        }
    }
    "developer" {
        Write-ColoredOutput "Using Developer profile with additional tools" "Cyan"
        if ($dockerComposeCmd -eq "docker-compose") {
            & docker-compose --profile developer up -d
            $success = $?
        } else {
            & docker compose --profile developer up -d
            $success = $?
        }
    }
}

if ($success) {
    Write-ColoredOutput "✅ N8N AI Starter Kit successfully started with $Profile profile!" "Green"
    Write-ColoredOutput "Access services at:" "Cyan"
    Write-ColoredOutput "• N8N: http://localhost:5678" "Cyan"
    Write-ColoredOutput "• Ollama: http://localhost:11434" "Cyan"
    Write-ColoredOutput "• Traefik Dashboard: http://localhost:8080" "Cyan"
    
    # If developer profile, show additional services
    if ($Profile -eq "developer") {
        Write-ColoredOutput "• JupyterLab: http://localhost:8888" "Cyan"
        Write-ColoredOutput "• pgAdmin: http://localhost:5050" "Cyan"
    }
    
    Write-ColoredOutput "To check the logs, run: $dockerComposeCmd logs -f" "Cyan"
    Write-ColoredOutput "To stop the application, run: $dockerComposeCmd down" "Cyan"
} else {
    Write-ColoredOutput "❌ Failed to start N8N AI Starter Kit. Check the docker-compose logs for details." "Red"
    exit 1
}
