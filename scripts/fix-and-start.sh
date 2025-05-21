#!/bin/bash
# Script to fix environment variables and then start the n8n-ai-starter-kit application

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

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo_color "$RED" "Error: docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo_color "$RED" "Error: docker-compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Step 1: Run the fix-env-vars script
echo_color "$YELLOW" "Step 1: Fixing environment variables..."
if [ -f "./scripts/fix-env-vars.sh" ]; then
    bash ./scripts/fix-env-vars.sh
    
    if [ $? -ne 0 ]; then
        echo_color "$RED" "Error fixing environment variables. Aborting."
        exit 1
    fi
else
    echo_color "$RED" "Error: fix-env-vars.sh script not found."
    echo_color "$YELLOW" "Please make sure you're running this script from the project root directory."
    exit 1
fi

# Step 2: Start the application with docker-compose
echo_color "$YELLOW" "Step 2: Starting the application with docker-compose..."

# Determine which docker compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    DOCKER_COMPOSE_CMD="docker compose"
fi

# Stop any existing containers first
echo_color "$CYAN" "Stopping any existing containers..."
$DOCKER_COMPOSE_CMD down

# Start the containers
echo_color "$CYAN" "Starting the containers..."
$DOCKER_COMPOSE_CMD up -d

if [ $? -eq 0 ]; then
    echo_color "$GREEN" "✅ Application successfully started!"
    echo_color "$CYAN" "You can access the n8n interface at: http://localhost:5678"
    echo_color "$CYAN" "To check the logs, run: docker-compose logs -f"
    echo_color "$CYAN" "To stop the application, run: docker-compose down"
else
    echo_color "$RED" "❌ Failed to start the application. Check the docker-compose logs for details."
    exit 1
fi
