#!/bin/bash

# Health Check Script for N8N AI Starter Kit Logging Stack
# This script checks the health of all logging components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "🔍 N8N AI Starter Kit - Logging Stack Health Check"
echo "=================================================="
echo "Timestamp: $(date)"
echo ""

# Function to check service health
check_service_health() {
    local service_name=$1
    local health_url=$2
    local expected_status=${3:-200}
    
    echo -n "🔍 Checking $service_name... "
    
    if response=$(curl -s -w "%{http_code}" -o /dev/null "$health_url" 2>/dev/null); then
        if [ "$response" = "$expected_status" ]; then
            echo "✅ Healthy (HTTP $response)"
            return 0
        else
            echo "❌ Unhealthy (HTTP $response)"
            return 1
        fi
    else
        echo "❌ Not responding"
        return 1
    fi
}

# Function to check disk usage
check_disk_usage() {
    echo "💾 Disk Usage Analysis"
    echo "====================="
    
    # Check logs directory
    if [ -d "$PROJECT_ROOT/logs" ]; then
        local logs_size=$(du -sh "$PROJECT_ROOT/logs" 2>/dev/null | cut -f1)
        echo "📁 Logs directory size: $logs_size"
    fi
    
    # Check data directory
    if [ -d "$PROJECT_ROOT/data" ]; then
        local data_size=$(du -sh "$PROJECT_ROOT/data" 2>/dev/null | cut -f1)
        echo "📁 Data directory size: $data_size"
    fi
    
    # Check overall disk usage
    local disk_usage=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "💿 Overall disk usage: ${disk_usage}%"
    
    if [ "$disk_usage" -gt 90 ]; then
        echo "⚠️  WARNING: Disk usage is high (${disk_usage}%)"
    elif [ "$disk_usage" -gt 80 ]; then
        echo "⚠️  CAUTION: Disk usage is above 80% (${disk_usage}%)"
    else
        echo "✅ Disk usage is acceptable (${disk_usage}%)"
    fi
    
    echo ""
}

# Function to check Docker containers
check_containers() {
    echo "🐳 Container Status"
    echo "=================="
    
    local compose_file="$PROJECT_ROOT/compose/logging-compose.yml"
    
    if [ -f "$compose_file" ]; then
        cd "$PROJECT_ROOT"
        
        # Get container status
        local containers=(
            "n8n_elasticsearch"
            "n8n_logstash"
            "n8n_kibana"
            "n8n_filebeat"
            "n8n_log_rotator"
        )
        
        for container in "${containers[@]}"; do
            if docker ps --format "table {{.Names}}" | grep -q "$container"; then
                local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
                local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
                
                if [ "$status" = "running" ]; then
                    if [ "$health" = "healthy" ] || [ "$health" = "<no value>" ]; then
                        echo "✅ $container: Running"
                    else
                        echo "⚠️  $container: Running but health check failed ($health)"
                    fi
                else
                    echo "❌ $container: $status"
                fi
            else
                echo "❌ $container: Not found"
            fi
        done
    else
        echo "❌ Compose file not found: $compose_file"
    fi
    
    echo ""
}

# Function to check service APIs
check_apis() {
    echo "🌐 API Health Checks"
    echo "==================="
    
    local services_healthy=0
    local total_services=0
    
    # Elasticsearch
    total_services=$((total_services + 1))
    if check_service_health "Elasticsearch" "http://localhost:9200/_cluster/health"; then
        services_healthy=$((services_healthy + 1))
        
        # Get cluster status
        local cluster_status=$(curl -s "http://localhost:9200/_cluster/health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
        if [ "$cluster_status" = "green" ]; then
            echo "   📊 Cluster status: Green ✅"
        elif [ "$cluster_status" = "yellow" ]; then
            echo "   📊 Cluster status: Yellow ⚠️"
        elif [ "$cluster_status" = "red" ]; then
            echo "   📊 Cluster status: Red ❌"
        fi
        
        # Get index count
        local index_count=$(curl -s "http://localhost:9200/_cat/indices?h=index" | wc -l 2>/dev/null)
        echo "   📋 Indices count: $index_count"
    fi
    
    # Logstash
    total_services=$((total_services + 1))
    if check_service_health "Logstash" "http://localhost:9600/_node/stats"; then
        services_healthy=$((services_healthy + 1))
        
        # Get pipeline stats
        local pipeline_count=$(curl -s "http://localhost:9600/_node/stats/pipelines" | grep -o '"pipeline"' | wc -l 2>/dev/null)
        echo "   📈 Active pipelines: $pipeline_count"
    fi
    
    # Kibana
    total_services=$((total_services + 1))
    if check_service_health "Kibana" "http://localhost:5601/api/status"; then
        services_healthy=$((services_healthy + 1))
        
        # Get Kibana status
        local kibana_status=$(curl -s "http://localhost:5601/api/status" | grep -o '"level":"[^"]*"' | cut -d'"' -f4 2>/dev/null | head -1)
        echo "   📊 Kibana status: $kibana_status"
    fi
    
    echo ""
    echo "📊 Overall API Health: $services_healthy/$total_services services healthy"
    
    if [ "$services_healthy" -eq "$total_services" ]; then
        echo "✅ All services are healthy"
    elif [ "$services_healthy" -gt 0 ]; then
        echo "⚠️  Some services are unhealthy"
    else
        echo "❌ All services are unhealthy"
    fi
    
    echo ""
}

# Function to check log ingestion
check_log_ingestion() {
    echo "📊 Log Ingestion Status"
    echo "======================"
    
    # Check recent documents in Elasticsearch
    if curl -s "http://localhost:9200/_cluster/health" &> /dev/null; then
        
        # Get document counts for different indices
        local indices=("logstash-general-*" "n8n-logs-*" "docker-logs-*" "system-logs-*")
        
        for index in "${indices[@]}"; do
            local count=$(curl -s "http://localhost:9200/${index}/_count" | grep -o '"count":[0-9]*' | cut -d':' -f2 2>/dev/null)
            if [ -n "$count" ] && [ "$count" -gt 0 ]; then
                echo "✅ $index: $count documents"
            else
                echo "⚠️  $index: No documents found"
            fi
        done
        
        # Check recent documents (last hour)
        local recent_docs=$(curl -s "http://localhost:9200/_search" -H "Content-Type: application/json" -d '{
            "query": {
                "range": {
                    "@timestamp": {
                        "gte": "now-1h"
                    }
                }
            },
            "size": 0
        }' | grep -o '"total":{"value":[0-9]*' | cut -d':' -f3 | cut -d',' -f1 2>/dev/null)
        
        if [ -n "$recent_docs" ] && [ "$recent_docs" -gt 0 ]; then
            echo "✅ Recent activity: $recent_docs documents in last hour"
        else
            echo "⚠️  No recent log activity detected"
        fi
        
    else
        echo "❌ Cannot check log ingestion - Elasticsearch not available"
    fi
    
    echo ""
}

# Function to check network connectivity
check_network() {
    echo "🌐 Network Connectivity"
    echo "======================"
    
    # Check if networks exist
    if docker network ls | grep -q "n8n_logging"; then
        echo "✅ n8n_logging network exists"
    else
        echo "❌ n8n_logging network missing"
    fi
    
    if docker network ls | grep -q "n8n_network"; then
        echo "✅ n8n_network network exists"
    else
        echo "❌ n8n_network network missing"
    fi
    
    echo ""
}

# Function to generate summary report
generate_summary() {
    echo "📋 Health Check Summary"
    echo "======================"
    
    local timestamp=$(date)
    local overall_status="HEALTHY"
    
    # Determine overall status
    if ! curl -s "http://localhost:9200/_cluster/health" &> /dev/null; then
        overall_status="CRITICAL"
    elif ! curl -s "http://localhost:5601/api/status" &> /dev/null; then
        overall_status="DEGRADED"
    elif ! curl -s "http://localhost:9600/_node/stats" &> /dev/null; then
        overall_status="DEGRADED"
    fi
    
    echo "🕐 Timestamp: $timestamp"
    echo "📊 Overall Status: $overall_status"
    echo "🔧 Project: N8N AI Starter Kit v1.2.0"
    echo "📍 Component: Logging Stack (Stage 3.2)"
    
    if [ "$overall_status" = "HEALTHY" ]; then
        echo "✅ All systems operational"
    elif [ "$overall_status" = "DEGRADED" ]; then
        echo "⚠️  Some components need attention"
    else
        echo "❌ Critical issues detected"
    fi
    
    echo ""
    echo "🔗 Quick Links:"
    echo "  📊 Kibana Dashboard: http://localhost:5601"
    echo "  🔍 Elasticsearch: http://localhost:9200"
    echo "  📈 Logstash API: http://localhost:9600"
    echo ""
    echo "📚 Documentation:"
    echo "  📖 Logging Guide: docs/LOGGING_SETUP_GUIDE.md"
    echo "  🚨 Troubleshooting: TROUBLESHOOTING.md"
}

# Main execution
main() {
    check_containers
    check_apis
    check_disk_usage
    check_log_ingestion
    check_network
    generate_summary
    
    echo "=============================================="
    echo "Health check completed at $(date)"
}

# Run main function
main "$@"
