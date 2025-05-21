#!/bin/bash
# Script to start n8n-ai-starter-kit with the specified profile
# Usage: ./scripts/start.sh [cpu|gpu-nvidia|gpu-amd|developer]

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
    echo_color "$RED" "Error: Profile not specified"
    echo_color "$YELLOW" "Usage: $0 [cpu|gpu-nvidia|gpu-amd|developer]"
    echo_color "$YELLOW" "Examples:"
    echo_color "$YELLOW" "  $0 cpu          # Start with CPU profile (default)"
    echo_color "$YELLOW" "  $0 gpu-nvidia   # Start with NVIDIA GPU profile"
    echo_color "$YELLOW" "  $0 gpu-amd      # Start with AMD GPU profile"
    echo_color "$YELLOW" "  $0 developer    # Start with developer profile (includes additional tools)"
    exit 1
fi

# Validate profile
PROFILE="$1"
case "$PROFILE" in
    cpu|gpu-nvidia|gpu-amd|developer)
        # Valid profile
        ;;
    *)
        echo_color "$RED" "Error: Invalid profile '$PROFILE'"
        echo_color "$YELLOW" "Valid profiles: cpu, gpu-nvidia, gpu-amd, developer"
        exit 1
        ;;
esac

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

# Start with selected profile
echo_color "$CYAN" "Starting N8N AI Starter Kit with $PROFILE profile..."

case "$PROFILE" in
    cpu)
        echo_color "$CYAN" "Using CPU profile for AI services"
        $DOCKER_COMPOSE_CMD --profile cpu up -d
        ;;
    gpu-nvidia)
        echo_color "$CYAN" "Using NVIDIA GPU profile for AI services"
        $DOCKER_COMPOSE_CMD --profile gpu-nvidia up -d
        ;;
    gpu-amd)
        echo_color "$CYAN" "Using AMD GPU profile for AI services"
        $DOCKER_COMPOSE_CMD --profile gpu-amd up -d
        ;;
    developer)
        echo_color "$CYAN" "Using Developer profile with additional tools"
        $DOCKER_COMPOSE_CMD --profile developer up -d
        ;;
esac

if [ $? -eq 0 ]; then
    echo_color "$GREEN" "✅ N8N AI Starter Kit successfully started with $PROFILE profile!"
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
else
    echo_color "$RED" "❌ Failed to start N8N AI Starter Kit. Check the docker-compose logs for details."
    exit 1
fi
