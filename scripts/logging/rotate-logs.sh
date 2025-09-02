#!/bin/bash

# Log rotation script for N8N AI Starter Kit
# This script rotates logs to prevent disk space issues

set -e

LOG_DIR="/app/logs"
DAYS_TO_KEEP=30
COMPRESS_OLDER_THAN=7

echo "Starting log rotation at $(date)"

# Function to rotate logs for a specific service
rotate_service_logs() {
    local service=$1
    local service_log_dir="${LOG_DIR}/${service}"
    
    if [ -d "$service_log_dir" ]; then
        echo "Rotating logs for service: $service"
        
        # Find and rotate logs older than specified days
        find "$service_log_dir" -name "*.log" -type f -mtime +$DAYS_TO_KEEP -delete
        echo "Deleted logs older than $DAYS_TO_KEEP days for $service"
        
        # Compress logs older than specified days
        find "$service_log_dir" -name "*.log" -type f -mtime +$COMPRESS_OLDER_THAN ! -name "*.gz" -exec gzip {} \;
        echo "Compressed logs older than $COMPRESS_OLDER_THAN days for $service"
        
        # Remove compressed logs older than retention period
        find "$service_log_dir" -name "*.gz" -type f -mtime +$DAYS_TO_KEEP -delete
        echo "Deleted compressed logs older than $DAYS_TO_KEEP days for $service"
    else
        echo "Log directory not found for service: $service"
    fi
}

# Function to get disk usage
get_disk_usage() {
    df -h "$LOG_DIR" | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Check disk usage before rotation
INITIAL_USAGE=$(get_disk_usage)
echo "Initial disk usage: ${INITIAL_USAGE}%"

# Rotate logs for each service
SERVICES=("n8n" "ollama" "qdrant" "postgresql" "elasticsearch" "logstash" "kibana" "filebeat")

for service in "${SERVICES[@]}"; do
    rotate_service_logs "$service"
done

# Rotate general application logs
if [ -d "$LOG_DIR" ]; then
    echo "Rotating general application logs"
    find "$LOG_DIR" -maxdepth 1 -name "*.log" -type f -mtime +$DAYS_TO_KEEP -delete
    find "$LOG_DIR" -maxdepth 1 -name "*.log" -type f -mtime +$COMPRESS_OLDER_THAN ! -name "*.gz" -exec gzip {} \;
    find "$LOG_DIR" -maxdepth 1 -name "*.gz" -type f -mtime +$DAYS_TO_KEEP -delete
fi

# Clean up empty directories
find "$LOG_DIR" -type d -empty -delete 2>/dev/null || true

# Check disk usage after rotation
FINAL_USAGE=$(get_disk_usage)
echo "Final disk usage: ${FINAL_USAGE}%"

# Calculate space saved
SPACE_SAVED=$((INITIAL_USAGE - FINAL_USAGE))
if [ $SPACE_SAVED -gt 0 ]; then
    echo "Space saved: ${SPACE_SAVED}%"
else
    echo "No significant space saved"
fi

# Log rotation summary
echo "Log rotation completed at $(date)"
echo "----------------------------------------"
echo "Configuration:"
echo "  - Days to keep: $DAYS_TO_KEEP"
echo "  - Compress older than: $COMPRESS_OLDER_THAN days"
echo "  - Log directory: $LOG_DIR"
echo "  - Services rotated: ${#SERVICES[@]}"
echo "----------------------------------------"

# Check if disk usage is still high
if [ "$FINAL_USAGE" -gt 90 ]; then
    echo "WARNING: Disk usage is still high (${FINAL_USAGE}%)"
    echo "Consider reducing retention period or checking for other space usage"
fi

exit 0
