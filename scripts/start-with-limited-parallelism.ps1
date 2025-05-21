# PowerShell script to start n8n-ai-starter-kit with limited execution parallelism
# This helps avoid rate limits with AI providers

param (
    [int]$MaxParallelism = 2
)

# Function to display colored console messages
function Write-ColoredOutput {
    param (
        [string]$message,
        [string]$color = "White"
    )
    Write-Host $message -ForegroundColor $color
}

# Help message
if ($args -contains "-h" -or $args -contains "--help") {
    Write-ColoredOutput "Usage: .\start-with-limited-parallelism.ps1 [-MaxParallelism <number>]" "Cyan"
    Write-ColoredOutput "  -MaxParallelism: Set maximum execution parallelism (default: 2)" "Cyan"
    exit 0
}

# Validate MAX_PARALLELISM
if ($MaxParallelism -lt 1) {
    Write-ColoredOutput "Error: Parallelism must be a positive integer" "Red"
    exit 1
}

# Override environment file
$OVERRIDE_ENV_FILE = ".env.limited-parallelism"

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

# Create override environment file
Write-ColoredOutput "Creating environment configuration with max parallelism of $MaxParallelism..." "Yellow"

"# Generated override settings for limited parallelism" | Out-File -FilePath $OVERRIDE_ENV_FILE -Encoding utf8
"N8N_PARALLEL_EXECUTION_MAX=$MaxParallelism" | Add-Content -Path $OVERRIDE_ENV_FILE
"N8N_AI_EXECUTION_LIMITER_MAX_CONCURRENCY=$MaxParallelism" | Add-Content -Path $OVERRIDE_ENV_FILE

Write-ColoredOutput "Created $OVERRIDE_ENV_FILE with limited parallelism settings" "Green"

# First run the fix-env-vars script to ensure environment is properly set up
Write-ColoredOutput "Fixing environment variables..." "Yellow"
if (Test-Path "./scripts/fix-env-vars.ps1") {
    & powershell -ExecutionPolicy Bypass -File "./scripts/fix-env-vars.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Error fixing environment variables. Aborting." "Red"
        exit 1
    }
} else {
    Write-ColoredOutput "Warning: fix-env-vars.ps1 script not found. Continuing without fixing environment variables." "Red"
}

# Stop any existing containers first
Write-ColoredOutput "Stopping any existing containers..." "Cyan"
if ($dockerComposeCmd -eq "docker-compose") {
    & docker-compose down
} else {
    & docker compose down
}

# Start the containers with environment override
Write-ColoredOutput "Starting the containers with limited parallelism ($MaxParallelism)..." "Cyan"

# Read the original .env file
$envVars = @{}
if (Test-Path ".env") {
    Get-Content -Path ".env" | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            $key = $matches[1]
            $value = $matches[2]
            $envVars[$key] = $value
        }
    }
}

# Add the override variables
$envVars["N8N_PARALLEL_EXECUTION_MAX"] = $MaxParallelism
$envVars["N8N_AI_EXECUTION_LIMITER_MAX_CONCURRENCY"] = $MaxParallelism

# Build the environment variable string for the command
$envString = ""
foreach ($key in $envVars.Keys) {
    $envString += "$key=$($envVars[$key]) "
}

# Run docker-compose with the combined environment variables
if ($dockerComposeCmd -eq "docker-compose") {
    $command = "$envString docker-compose up -d"
    Invoke-Expression "cmd /c `"$command`""
    $success = $?
} else {
    $command = "$envString docker compose up -d"
    Invoke-Expression "cmd /c `"$command`""
    $success = $?
}

if ($success) {
    Write-ColoredOutput "✅ Application successfully started with limited parallelism!" "Green"
    Write-ColoredOutput "Executions will be limited to $MaxParallelism in parallel." "Cyan"
    Write-ColoredOutput "You can access the n8n interface at: http://localhost:5678" "Cyan"
    Write-ColoredOutput "To check the logs, run: docker-compose logs -f" "Cyan"
    Write-ColoredOutput "To stop the application, run: docker-compose down" "Cyan"
} else {
    Write-ColoredOutput "❌ Failed to start the application. Check the docker-compose logs for details." "Red"
    exit 1
}
