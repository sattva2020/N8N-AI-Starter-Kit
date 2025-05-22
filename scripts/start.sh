#!/bin/bash
# Script to start n8n-ai-starter-kit with the specified profile
# Usage: ./scripts/start.sh [cpu|gpu-nvidia|gpu-amd|developer]

set -e  # Exit script on error

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display colored console messages
function echo_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if profile argument is provided
if [ -z "$1" ]; then
    PROFILE="cpu"
    echo_color "$YELLOW" "No profile specified, using default: $PROFILE"
else
    PROFILE="$1"
fi

echo_color "$CYAN" "Using $PROFILE profile for AI services"

# Set parallelism limit for Docker Compose
export COMPOSE_PARALLEL_LIMIT=1

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo_color "$RED" "Error: docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo_color "$RED" "Error: docker-compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Determine which docker compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

# First run the fix-env-vars script to ensure environment is properly set up
echo_color "$YELLOW" "Checking and fixing environment variables..."
if [ -f "./scripts/fix-env-vars.sh" ]; then
    bash ./scripts/fix-env-vars.sh
    
    if [ $? -ne 0 ]; then
        echo_color "$RED" "Error fixing environment variables. Continuing without fixes..."
    fi
else
    echo_color "$YELLOW" "Warning: fix-env-vars.sh not found. Continuing without fixing environment variables."
fi

# Stop any existing containers first
echo_color "$CYAN" "Stopping any existing containers..."
$DOCKER_COMPOSE_CMD down

# Prune unused networks to prevent conflicts
echo_color "$CYAN" "Pruning unused networks..."
docker network prune -f

# Start with selected profile
echo_color "$CYAN" "Starting N8N AI Starter Kit with $PROFILE profile..."

$DOCKER_COMPOSE_CMD --profile $PROFILE up -d || {
  echo_color "$RED" "❌ Failed to start N8N AI Starter Kit. Check the docker-compose logs for details."
  exit 1
}

echo_color "$GREEN" "✅ N8N AI Starter Kit started successfully with $PROFILE profile!"
echo_color "$CYAN" "Access services at:"
echo_color "$CYAN" "• N8N: http://localhost:5678"
echo_color "$CYAN" "• Ollama: http://localhost:11434"
echo_color "$CYAN" "• Traefik Dashboard: http://localhost:8080"
    
# If developer profile, show additional services
if [ "$PROFILE" == "developer" ]; then
    echo_color "$CYAN" "• JupyterLab: http://localhost:8888"
    echo_color "$CYAN" "• pgAdmin: http://localhost:5050"
fi
    
echo_color "$CYAN" "To check the logs, run: $DOCKER_COMPOSE_CMD logs -f"
echo_color "$CYAN" "To stop the application, run: $DOCKER_COMPOSE_CMD down"

if [ ! -f .env ]; then
  echo "Ошибка: файл .env не найден. Запустите ./scripts/setup.sh"
  exit 1
fi
