#!/bin/bash

# Deploy Logging Stack for N8N AI Starter Kit
# This script deploys the ELK stack with Filebeat for centralized logging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMPOSE_FILE="$PROJECT_ROOT/compose/logging-compose.yml"

echo "🚀 Deploying N8N AI Starter Kit Logging Stack"
echo "=============================================="

# Function to check if required directories exist
check_directories() {
    echo "📁 Checking required directories..."
    
    local dirs=(
        "$PROJECT_ROOT/data/elasticsearch"
        "$PROJECT_ROOT/data/kibana"
        "$PROJECT_ROOT/data/filebeat"
        "$PROJECT_ROOT/logs"
        "$PROJECT_ROOT/logs/elasticsearch"
        "$PROJECT_ROOT/logs/logstash"
        "$PROJECT_ROOT/logs/kibana"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    # Set proper permissions for Elasticsearch
    chmod 777 "$PROJECT_ROOT/data/elasticsearch" 2>/dev/null || sudo chmod 777 "$PROJECT_ROOT/data/elasticsearch"
    echo "✅ Directories checked and created"
}

# Function to check system requirements
check_system_requirements() {
    echo "🔧 Checking system requirements..."
    
    # Check available memory
    AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$AVAILABLE_MEMORY" -lt 2048 ]; then
        echo "⚠️  WARNING: Available memory is less than 2GB. ELK stack may not perform well."
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Set vm.max_map_count for Elasticsearch
    echo "Setting vm.max_map_count for Elasticsearch..."
    if command -v sysctl &> /dev/null; then
        sudo sysctl -w vm.max_map_count=262144 2>/dev/null || echo "⚠️  Could not set vm.max_map_count (might need sudo)"
    fi
    
    echo "✅ System requirements checked"
}

# Function to create Docker network
create_network() {
    echo "🌐 Creating Docker network..."
    
    if ! docker network ls | grep -q "n8n_logging"; then
        docker network create n8n_logging
        echo "✅ Created n8n_logging network"
    else
        echo "✅ n8n_logging network already exists"
    fi
    
    if ! docker network ls | grep -q "n8n_network"; then
        docker network create n8n_network
        echo "✅ Created n8n_network network"
    else
        echo "✅ n8n_network network already exists"
    fi
}

# Function to deploy logging stack
deploy_logging_stack() {
    echo "📊 Deploying logging stack..."
    
    cd "$PROJECT_ROOT"
    
    # Pull latest images
    echo "Pulling latest images..."
    docker-compose -f "$COMPOSE_FILE" pull
    
    # Start services
    echo "Starting logging services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    echo "✅ Logging stack deployed"
}

# Function to wait for services to be ready
wait_for_services() {
    echo "⏳ Waiting for services to be ready..."
    
    # Wait for Elasticsearch
    echo "Waiting for Elasticsearch..."
    for i in {1..30}; do
        if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
            echo "✅ Elasticsearch is ready"
            break
        fi
        echo "Waiting for Elasticsearch... ($i/30)"
        sleep 10
    done
    
    # Wait for Logstash
    echo "Waiting for Logstash..."
    for i in {1..20}; do
        if curl -s http://localhost:9600/_node/stats &> /dev/null; then
            echo "✅ Logstash is ready"
            break
        fi
        echo "Waiting for Logstash... ($i/20)"
        sleep 10
    done
    
    # Wait for Kibana
    echo "Waiting for Kibana..."
    for i in {1..30}; do
        if curl -s http://localhost:5601/api/status &> /dev/null; then
            echo "✅ Kibana is ready"
            break
        fi
        echo "Waiting for Kibana... ($i/30)"
        sleep 10
    done
    
    echo "✅ All services are ready"
}

# Function to create index patterns
create_index_patterns() {
    echo "📋 Creating index patterns..."
    
    # Wait a bit more for Kibana to fully initialize
    sleep 30
    
    # Create index patterns via Kibana API
    local index_patterns=(
        "logstash-general-*"
        "n8n-logs-*"
        "docker-logs-*"
        "system-logs-*"
    )
    
    for pattern in "${index_patterns[@]}"; do
        echo "Creating index pattern: $pattern"
        curl -X POST "localhost:5601/api/saved_objects/index-pattern" \
            -H "Content-Type: application/json" \
            -H "kbn-xsrf: true" \
            -d "{
                \"attributes\": {
                    \"title\": \"$pattern\",
                    \"timeFieldName\": \"@timestamp\"
                }
            }" &> /dev/null || echo "Index pattern $pattern might already exist"
    done
    
    echo "✅ Index patterns created"
}

# Function to show service status
show_service_status() {
    echo "📊 Service Status"
    echo "=================="
    
    cd "$PROJECT_ROOT"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "🌐 Service URLs:"
    echo "  Elasticsearch: http://localhost:9200"
    echo "  Kibana: http://localhost:5601"
    echo "  Logstash API: http://localhost:9600"
    echo ""
    echo "🔍 Health Checks:"
    
    # Elasticsearch health
    if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
        echo "  ✅ Elasticsearch: Healthy"
    else
        echo "  ❌ Elasticsearch: Not responding"
    fi
    
    # Logstash health
    if curl -s http://localhost:9600/_node/stats &> /dev/null; then
        echo "  ✅ Logstash: Healthy"
    else
        echo "  ❌ Logstash: Not responding"
    fi
    
    # Kibana health
    if curl -s http://localhost:5601/api/status &> /dev/null; then
        echo "  ✅ Kibana: Healthy"
    else
        echo "  ❌ Kibana: Not responding"
    fi
}

# Main execution
main() {
    echo "Starting deployment at $(date)"
    
    check_directories
    check_system_requirements
    create_network
    deploy_logging_stack
    wait_for_services
    create_index_patterns
    show_service_status
    
    echo ""
    echo "🎉 Logging stack deployment completed!"
    echo "========================================="
    echo "Access Kibana at: http://localhost:5601"
    echo "Access Elasticsearch at: http://localhost:9200"
    echo "Logs will be automatically collected and indexed."
    echo ""
    echo "Next steps:"
    echo "1. Open Kibana and explore the dashboards"
    echo "2. Create custom visualizations for your needs"
    echo "3. Set up alerting rules in Elasticsearch"
    echo "4. Configure log retention policies"
    echo ""
    echo "For troubleshooting, check service logs:"
    echo "  docker-compose -f $COMPOSE_FILE logs [service_name]"
}

# Run main function
main "$@"
