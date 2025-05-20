# Script to fix environment variables and start n8n AI Starter Kit on Windows
# Created: May 19, 2025

# Define colors for output
function Write-Color {
  param ([string]$Message, [string]$Color = "White")
  Write-Host $Message -ForegroundColor $Color
}

Write-Color "Starting n8n AI Starter Kit with all fixes..." "Cyan"

# Step 1: Stop any running containers
Write-Color "Stopping running containers..." "Yellow"
docker-compose down

# Step 2: Clean up unused networks
Write-Color "Cleaning up Docker networks..." "Yellow"
docker network prune -f

# Step 3: Fix environment variables
Write-Color "Fixing environment variables..." "Yellow"

# Check if the .env file exists
if (Test-Path ".env") {
  # Run the environment variable fix script
  if (Test-Path ".\scripts\fix-env-vars.ps1") {
    Write-Color "Running fix-env-vars.ps1..." "Yellow"
    & ".\scripts\fix-env-vars.ps1"
  }
  else {
    Write-Color "Script fix-env-vars.ps1 not found. Applying manual fix..." "Yellow"
        
    $envContent = Get-Content ".env" -Raw
    $modified = $false
        
    # Check ANON_KEY
    if ($envContent -match "SUPABASE_ANON_KEY=(.+)(?:\r?\n|$)" -and (-not ($envContent -match "^ANON_KEY="))) {
      $anonValue = $Matches[1].Trim()
      Add-Content ".env" "`n# ---- SUPABASE ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ----"
      Add-Content ".env" "ANON_KEY=$anonValue"
      Write-Color "✅ Added ANON_KEY variable" "Green"
      $modified = $true
    }
        
    # Check SERVICE_ROLE_KEY
    if ($envContent -match "SUPABASE_SERVICE_ROLE_KEY=(.+)(?:\r?\n|$)" -and (-not ($envContent -match "^SERVICE_ROLE_KEY="))) {
      $serviceKeyValue = $Matches[1].Trim()
      Add-Content ".env" "SERVICE_ROLE_KEY=$serviceKeyValue"
      Write-Color "✅ Added SERVICE_ROLE_KEY variable" "Green"
      $modified = $true
    }
        
    # Check JWT_SECRET
    if ($envContent -match "SUPABASE_JWT_SECRET=(.+)(?:\r?\n|$)" -and (-not ($envContent -match "^JWT_SECRET="))) {
      $jwtSecretValue = $Matches[1].Trim()
      Add-Content ".env" "JWT_SECRET=$jwtSecretValue"
      Write-Color "✅ Added JWT_SECRET variable" "Green"
      $modified = $true
    }
        
    if (-not $modified) {
      Write-Color "All required environment variables are already defined." "Green"
    }
  }
}
else {
  Write-Color "❌ .env file not found. Please run setup.sh first or create an .env file manually." "Red"
  exit 1
}

# Step 4: Set limited parallelism
Write-Color "Setting limited parallelism for Docker Compose..." "Yellow"
$env:COMPOSE_PARALLEL_LIMIT = 1
Write-Color "✅ Set COMPOSE_PARALLEL_LIMIT=1" "Green"

# Step 5: Start the system
Write-Color "Starting the system with CPU profile..." "Yellow"
docker-compose --profile cpu up -d

# Step 6: Check system status
Write-Color "Waiting for services to start..." "Yellow"
Start-Sleep -Seconds 5
Write-Color "Checking container status:" "Yellow"
docker-compose ps

Write-Color "`nSystem started with all necessary fixes!" "Green"
Write-Color "If you encounter any issues, check the logs with: docker-compose logs -f [service-name]" "Cyan"
Write-Color "To access the n8n interface, go to http://localhost:5678" "Cyan"
