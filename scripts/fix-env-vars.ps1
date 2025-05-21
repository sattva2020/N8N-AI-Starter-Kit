# PowerShell script to fix environment variables in .env file for n8n-ai-starter-kit
# This script addresses common issues with environment variables

# Function to display colored console messages
function Write-ColoredOutput {
    param (
        [string]$message,
        [string]$color = "White"
    )
    Write-Host $message -ForegroundColor $color
}

# Function to generate a random string
function Get-RandomString {
    param (
        [int]$length = 32,
        [string]$chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    )
    $random = New-Object char[] $length
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[] $length
    
    $rng.GetBytes($bytes)
    
    for ($i = 0; $i -lt $length; $i++) {
        $random[$i] = $chars[$bytes[$i] % $chars.Length]
    }
    
    return -join $random
}

$ENV_FILE = ".env"
$BACKUP_FILE = ".env.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Check if .env file exists
if (-not (Test-Path $ENV_FILE)) {
    Write-ColoredOutput "Error: .env file not found." "Red"
    Write-ColoredOutput "Please run this script from the root directory of the project." "Yellow"
    exit 1
}

# Create backup
Copy-Item $ENV_FILE -Destination $BACKUP_FILE
Write-ColoredOutput "Created backup of .env file: $BACKUP_FILE" "Green"

# Read the current .env file
$envContent = Get-Content $ENV_FILE -Raw

# Fix variables by copying values from Supabase to internal variables
$fixedVariables = @{
    "SUPABASE_URL" = "VITE_SUPABASE_URL"
    "SUPABASE_KEY" = "VITE_SUPABASE_ANON_KEY"
    "SUPABASE_JWT_SECRET" = "JWT_SECRET"
}

$modifications = 0
$envLines = Get-Content $ENV_FILE

# Process each line of the .env file
foreach ($pair in $fixedVariables.GetEnumerator()) {
    $sourceVar = $pair.Key
    $targetVar = $pair.Value
    
    # Extract value of source variable
    $sourceValue = $envLines | Where-Object { $_ -match "^$sourceVar=" } | ForEach-Object { $_ -replace "^$sourceVar=", "" }
    
    if ($sourceValue) {
        $sourceValue = $sourceValue.Trim('"''')
        # Check if target variable exists
        $targetExists = $envLines | Where-Object { $_ -match "^$targetVar=" }
        
        if ($targetExists) {
            # Replace existing target variable
            $envContent = $envContent -replace "^$targetVar=.*", "$targetVar=$sourceValue"
            Write-ColoredOutput "Updated: $targetVar set to value from $sourceVar" "Cyan"
        } else {
            # Add new target variable at the end
            $envContent += "`n$targetVar=$sourceValue"
            Write-ColoredOutput "Added: $targetVar with value from $sourceVar" "Green"
        }
        $modifications++
    }
}

# Check and add N8N_ENCRYPTION_KEY if missing
if (-not ($envContent -match "N8N_ENCRYPTION_KEY=")) {
    $randomKey = Get-RandomString -length 32
    $envContent += "`nN8N_ENCRYPTION_KEY=$randomKey"
    Write-ColoredOutput "Added: N8N_ENCRYPTION_KEY with generated value" "Green"
    $modifications++
}

# Check and add JWT_SECRET if missing
if (-not ($envContent -match "JWT_SECRET=")) {
    $randomJwt = Get-RandomString -length 32
    $envContent += "`nJWT_SECRET=$randomJwt"
    Write-ColoredOutput "Added: JWT_SECRET with generated value" "Green"
    $modifications++
}

# Write the updated content back to the .env file
$envContent | Set-Content $ENV_FILE

# Report results
if ($modifications -gt 0) {
    Write-ColoredOutput "Successfully made $modifications modifications to $ENV_FILE" "Green"
    Write-ColoredOutput "Your environment variables have been fixed!" "Green"
} else {
    Write-ColoredOutput "No modifications needed. Your .env file looks good!" "Green"
}

Write-ColoredOutput "You can now start the application with 'docker-compose up -d'" "Yellow"
