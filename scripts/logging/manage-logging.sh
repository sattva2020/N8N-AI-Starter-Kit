#!/bin/bash

# Logging Management Script for N8N AI Starter Kit
# This script provides comprehensive logging management functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
COMPOSE_FILE="$PROJECT_ROOT/compose/logging-compose.yml"

# Function to show usage
show_usage() {
    echo "N8N AI Starter Kit - Logging Management Tool"
    echo "==========================================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start          Start the logging stack"
    echo "  stop           Stop the logging stack"
    echo "  restart        Restart the logging stack"
    echo "  status         Show status of all logging services"
    echo "  health         Run comprehensive health check"
    echo "  logs           Show logs for specific service"
    echo "  clean          Clean up old logs and data"
    echo "  backup         Backup Elasticsearch data"
    echo "  restore        Restore Elasticsearch data"
    echo "  setup          Initial setup and configuration"
    echo "  monitor        Real-time monitoring of log ingestion"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all logging services"
    echo "  $0 logs elasticsearch       # Show Elasticsearch logs"
    echo "  $0 clean --days 30         # Clean logs older than 30 days"
    echo "  $0 backup /backup/path     # Backup to specific path"
    echo ""
}

# Function to start logging stack
start_logging() {
    echo "🚀 Starting N8N AI Starter Kit Logging Stack..."
    
    cd "$PROJECT_ROOT"
    
    # Check if compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Create networks if they don't exist
    docker network create n8n_logging 2>/dev/null || true
    docker network create n8n_network 2>/dev/null || true
    
    # Start services
    docker-compose -f "$COMPOSE_FILE" up -d
    
    echo "✅ Logging stack started"
    echo "📊 Access Kibana at: http://localhost:5601"
    echo "🔍 Access Elasticsearch at: http://localhost:9200"
}

# Function to stop logging stack
stop_logging() {
    echo "🛑 Stopping N8N AI Starter Kit Logging Stack..."
    
    cd "$PROJECT_ROOT"
    docker-compose -f "$COMPOSE_FILE" down
    
    echo "✅ Logging stack stopped"
}

# Function to restart logging stack
restart_logging() {
    echo "🔄 Restarting N8N AI Starter Kit Logging Stack..."
    
    stop_logging
    sleep 5
    start_logging
}

# Function to show status
show_status() {
    echo "📊 N8N AI Starter Kit Logging Stack Status"
    echo "==========================================="
    
    cd "$PROJECT_ROOT"
    
    if [ -f "$COMPOSE_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" ps
        
        echo ""
        echo "🌐 Service URLs:"
        echo "  Elasticsearch: http://localhost:9200"
        echo "  Kibana: http://localhost:5601"
        echo "  Logstash API: http://localhost:9600"
        
        echo ""
        echo "🔍 Quick Health Check:"
        
        # Quick health checks
        if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
            echo "  ✅ Elasticsearch: Responding"
        else
            echo "  ❌ Elasticsearch: Not responding"
        fi
        
        if curl -s http://localhost:5601/api/status &> /dev/null; then
            echo "  ✅ Kibana: Responding"
        else
            echo "  ❌ Kibana: Not responding"
        fi
        
        if curl -s http://localhost:9600/_node/stats &> /dev/null; then
            echo "  ✅ Logstash: Responding"
        else
            echo "  ❌ Logstash: Not responding"
        fi
    else
        echo "❌ Compose file not found: $COMPOSE_FILE"
    fi
}

# Function to show logs
show_logs() {
    local service=${1:-""}
    
    if [ -z "$service" ]; then
        echo "📋 Available services:"
        echo "  elasticsearch, logstash, kibana, filebeat, log-rotator"
        echo ""
        echo "Usage: $0 logs [service_name]"
        return 1
    fi
    
    echo "📋 Showing logs for: $service"
    echo "==============================="
    
    cd "$PROJECT_ROOT"
    docker-compose -f "$COMPOSE_FILE" logs -f "$service"
}

# Function to clean old logs and data
clean_logs() {
    local days=${1:-30}
    
    echo "🧹 Cleaning logs older than $days days..."
    
    # Run log rotation script
    if [ -f "$PROJECT_ROOT/scripts/logging/rotate-logs.sh" ]; then
        bash "$PROJECT_ROOT/scripts/logging/rotate-logs.sh"
    fi
    
    # Clean Elasticsearch indices older than specified days
    if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
        echo "🗂️  Cleaning old Elasticsearch indices..."
        
        # Get indices older than specified days
        local cutoff_date=$(date -d "-${days} days" +%Y.%m.%d)
        
        # Delete old indices
        curl -s "http://localhost:9200/_cat/indices?h=index" | while read index; do
            if [[ $index =~ [0-9]{4}\.[0-9]{2}\.[0-9]{2} ]]; then
                local index_date=$(echo "$index" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}')
                if [[ "$index_date" < "$cutoff_date" ]]; then
                    echo "Deleting old index: $index"
                    curl -X DELETE "http://localhost:9200/$index" &> /dev/null
                fi
            fi
        done
        
        echo "✅ Old indices cleaned"
    else
        echo "⚠️  Elasticsearch not available for index cleanup"
    fi
    
    echo "✅ Cleanup completed"
}

# Function to backup Elasticsearch data
backup_data() {
    local backup_path=${1:-"$PROJECT_ROOT/backup/elasticsearch"}
    
    echo "💾 Backing up Elasticsearch data to: $backup_path"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
        # Create snapshot repository
        curl -X PUT "http://localhost:9200/_snapshot/backup_repo" -H "Content-Type: application/json" -d "{
            \"type\": \"fs\",
            \"settings\": {
                \"location\": \"$backup_path\"
            }
        }" &> /dev/null
        
        # Create snapshot
        local snapshot_name="snapshot_$(date +%Y%m%d_%H%M%S)"
        curl -X PUT "http://localhost:9200/_snapshot/backup_repo/$snapshot_name?wait_for_completion=true" &> /dev/null
        
        echo "✅ Backup completed: $snapshot_name"
    else
        echo "❌ Elasticsearch not available for backup"
        exit 1
    fi
}

# Function to restore Elasticsearch data
restore_data() {
    local backup_path=${1:-"$PROJECT_ROOT/backup/elasticsearch"}
    local snapshot_name=$2
    
    if [ -z "$snapshot_name" ]; then
        echo "❌ Please specify snapshot name to restore"
        echo "Usage: $0 restore [backup_path] [snapshot_name]"
        exit 1
    fi
    
    echo "🔄 Restoring Elasticsearch data from: $snapshot_name"
    
    if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
        # Close indices before restore
        curl -X POST "http://localhost:9200/_all/_close" &> /dev/null
        
        # Restore snapshot
        curl -X POST "http://localhost:9200/_snapshot/backup_repo/$snapshot_name/_restore?wait_for_completion=true" &> /dev/null
        
        echo "✅ Restore completed: $snapshot_name"
    else
        echo "❌ Elasticsearch not available for restore"
        exit 1
    fi
}

# Function to run initial setup
setup_logging() {
    echo "⚙️  Running initial logging setup..."
    
    # Run deployment script
    if [ -f "$PROJECT_ROOT/scripts/logging/deploy-logging.sh" ]; then
        bash "$PROJECT_ROOT/scripts/logging/deploy-logging.sh"
    else
        echo "❌ Deployment script not found"
        exit 1
    fi
}

# Function to monitor log ingestion
monitor_logs() {
    echo "📊 Monitoring log ingestion (Press Ctrl+C to stop)..."
    echo "====================================================="
    
    while true; do
        clear
        echo "📊 Log Ingestion Monitor - $(date)"
        echo "=================================="
        
        if curl -s http://localhost:9200/_cluster/health &> /dev/null; then
            # Get document counts
            local total_docs=$(curl -s "http://localhost:9200/_cat/count?h=count" | tr -d ' \n')
            echo "📄 Total documents: $total_docs"
            
            # Get indices status
            echo ""
            echo "📂 Index Status:"
            curl -s "http://localhost:9200/_cat/indices?h=index,docs.count,store.size&s=index" | while read line; do
                echo "  $line"
            done
            
            # Get recent activity
            local recent_docs=$(curl -s "http://localhost:9200/_search" -H "Content-Type: application/json" -d '{
                "query": {
                    "range": {
                        "@timestamp": {
                            "gte": "now-1m"
                        }
                    }
                },
                "size": 0
            }' | grep -o '"total":{"value":[0-9]*' | cut -d':' -f3 | cut -d',' -f1 2>/dev/null)
            
            echo ""
            echo "⚡ Recent activity (last minute): $recent_docs documents"
            
        else
            echo "❌ Elasticsearch not available"
        fi
        
        sleep 10
    done
}

# Function to run health check
run_health_check() {
    if [ -f "$PROJECT_ROOT/scripts/logging/health-check.sh" ]; then
        bash "$PROJECT_ROOT/scripts/logging/health-check.sh"
    else
        echo "❌ Health check script not found"
        exit 1
    fi
}

# Main script logic
main() {
    local command=${1:-""}
    
    case $command in
        "start")
            start_logging
            ;;
        "stop")
            stop_logging
            ;;
        "restart")
            restart_logging
            ;;
        "status")
            show_status
            ;;
        "health")
            run_health_check
            ;;
        "logs")
            show_logs "$2"
            ;;
        "clean")
            clean_logs "$2"
            ;;
        "backup")
            backup_data "$2"
            ;;
        "restore")
            restore_data "$2" "$3"
            ;;
        "setup")
            setup_logging
            ;;
        "monitor")
            monitor_logs
            ;;
        "help"|"--help"|"-h"|"")
            show_usage
            ;;
        *)
            echo "❌ Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
