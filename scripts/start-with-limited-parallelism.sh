#!/bin/bash
# Script to start n8n-ai-starter-kit with limited execution parallelism
# This helps avoid rate limits with AI providers

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default configuration
MAX_PARALLELISM=2
OVERRIDE_ENV_FILE=".env.limited-parallelism"

# Function to display colored console messages
function echo_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Parse command line arguments
while getopts ":p:h" opt; do
  case $opt in
    p)
      MAX_PARALLELISM=$OPTARG
      ;;
    h)
      echo_color "$CYAN" "Usage: $0 [-p parallelism]"
      echo_color "$CYAN" "  -p: Set maximum execution parallelism (default: 2)"
      echo_color "$CYAN" "  -h: Show this help message"
      exit 0
      ;;
    \?)
      echo_color "$RED" "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      echo_color "$RED" "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done

# Validate MAX_PARALLELISM
if ! [[ "$MAX_PARALLELISM" =~ ^[0-9]+$ ]] || [ "$MAX_PARALLELISM" -lt 1 ]; then
    echo_color "$RED" "Error: Parallelism must be a positive integer"
    exit 1
fi

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo_color "$RED" "Error: docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo_color "$RED" "Error: docker-compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create override environment file
echo_color "$YELLOW" "Creating environment configuration with max parallelism of $MAX_PARALLELISM..."

echo "# Generated override settings for limited parallelism" > "$OVERRIDE_ENV_FILE"
echo "N8N_PARALLEL_EXECUTION_MAX=$MAX_PARALLELISM" >> "$OVERRIDE_ENV_FILE"
echo "N8N_AI_EXECUTION_LIMITER_MAX_CONCURRENCY=$MAX_PARALLELISM" >> "$OVERRIDE_ENV_FILE"

echo_color "$GREEN" "Created $OVERRIDE_ENV_FILE with limited parallelism settings"

# First run the fix-env-vars script to ensure environment is properly set up
echo_color "$YELLOW" "Fixing environment variables..."
if [ -f "./scripts/fix-env-vars.sh" ]; then
    bash ./scripts/fix-env-vars.sh
    
    if [ $? -ne 0 ]; then
        echo_color "$RED" "Error fixing environment variables. Aborting."
        exit 1
    fi
else
    echo_color "$RED" "Warning: fix-env-vars.sh script not found. Continuing without fixing environment variables."
fi

# Determine which docker compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Stop any existing containers first
echo_color "$CYAN" "Stopping any existing containers..."
$DOCKER_COMPOSE_CMD down

# Start the containers with environment override
echo_color "$CYAN" "Starting the containers with limited parallelism ($MAX_PARALLELISM)..."
$DOCKER_COMPOSE_CMD --env-file "$OVERRIDE_ENV_FILE" up -d

if [ $? -eq 0 ]; then
    echo_color "$GREEN" "✅ Application successfully started with limited parallelism!"
    echo_color "$CYAN" "Executions will be limited to $MAX_PARALLELISM in parallel."
    echo_color "$CYAN" "You can access the n8n interface at: http://localhost:5678"
    echo_color "$CYAN" "To check the logs, run: docker-compose logs -f"
    echo_color "$CYAN" "To stop the application, run: docker-compose down"
else
    echo_color "$RED" "❌ Failed to start the application. Check the docker-compose logs for details."
    exit 1
fi
