# PowerShell script to fix environment variables and then start the n8n-ai-starter-kit application

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

# Step 1: Run the fix-env-vars script
Write-ColoredOutput "Step 1: Fixing environment variables..." "Yellow"
if (Test-Path "./scripts/fix-env-vars.ps1") {
    & powershell -ExecutionPolicy Bypass -File "./scripts/fix-env-vars.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Error fixing environment variables. Aborting." "Red"
        exit 1
    }
} else {
    Write-ColoredOutput "Error: fix-env-vars.ps1 script not found." "Red"
    Write-ColoredOutput "Please make sure you're running this script from the project root directory." "Yellow"
    exit 1
}

# Step 2: Start the application with docker-compose
Write-ColoredOutput "Step 2: Starting the application with docker-compose..." "Yellow"

# Stop any existing containers first
Write-ColoredOutput "Stopping any existing containers..." "Cyan"
if ($dockerComposeCmd -eq "docker-compose") {
    & docker-compose down
} else {
    & docker compose down
}

# Start the containers
Write-ColoredOutput "Starting the containers..." "Cyan"
if ($dockerComposeCmd -eq "docker-compose") {
    & docker-compose up -d
    $success = $?
} else {
    & docker compose up -d
    $success = $?
}

if ($success) {
    Write-ColoredOutput "✅ Application successfully started!" "Green"
    Write-ColoredOutput "You can access the n8n interface at: http://localhost:5678" "Cyan"
    Write-ColoredOutput "To check the logs, run: docker-compose logs -f" "Cyan"
    Write-ColoredOutput "To stop the application, run: docker-compose down" "Cyan"
} else {
    Write-ColoredOutput "❌ Failed to start the application. Check the docker-compose logs for details." "Red"
    exit 1
}
