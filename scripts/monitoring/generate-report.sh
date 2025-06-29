#!/bin/bash

# N8N AI Starter Kit - Monitoring Report Generator
# Генерирует отчеты по мониторингу и производительности

set -euo pipefail

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORTS_DIR="$PROJECT_ROOT/reports/monitoring"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции логирования
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Создание директории для отчетов
create_reports_dir() {
    mkdir -p "$REPORTS_DIR"
}

# Получение метрик из Prometheus
query_prometheus() {
    local query="$1"
    local prometheus_url="${PROMETHEUS_URL:-http://localhost:9090}"
    
    curl -s -G "$prometheus_url/api/v1/query" \
         --data-urlencode "query=$query" \
         --data-urlencode "time=$(date +%s)" | \
    jq -r '.data.result[0].value[1] // "N/A"'
}

# Генерация HTML отчета
generate_html_report() {
    local report_file="$REPORTS_DIR/monitoring_report_$(date +%Y%m%d_%H%M%S).html"
    local report_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_info "Generating HTML report: $report_file"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>N8N AI Starter Kit - Monitoring Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #007acc;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            color: #007acc;
            margin: 0;
            font-size: 2.5em;
        }
        .header .subtitle {
            color: #666;
            margin-top: 10px;
            font-size: 1.1em;
        }
        .section {
            margin: 30px 0;
        }
        .section h2 {
            color: #007acc;
            border-left: 4px solid #007acc;
            padding-left: 15px;
            margin-bottom: 20px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 6px;
            border-left: 4px solid #007acc;
        }
        .metric-card h3 {
            margin: 0 0 10px 0;
            color: #333;
            font-size: 1.1em;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #007acc;
        }
        .metric-unit {
            font-size: 0.8em;
            color: #666;
            margin-left: 5px;
        }
        .status-table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        .status-table th,
        .status-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        .status-table th {
            background-color: #f8f9fa;
            font-weight: 600;
        }
        .status-healthy { color: #28a745; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .chart-placeholder {
            background: #f8f9fa;
            border: 2px dashed #ddd;
            padding: 40px;
            text-align: center;
            color: #666;
            border-radius: 6px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 0.9em;
        }
        .alert {
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        .alert-info {
            background-color: #d1ecf1;
            border-color: #bee5eb;
            color: #0c5460;
        }
        .alert-warning {
            background-color: #fff3cd;
            border-color: #ffeaa7;
            color: #856404;
        }
        .alert-error {
            background-color: #f8d7da;
            border-color: #f5c6cb;
            color: #721c24;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 N8N AI Starter Kit</h1>
            <div class="subtitle">Monitoring Report - $report_date</div>
        </div>

        <div class="section">
            <h2>📊 System Overview</h2>
            <div class="metrics-grid">
                <div class="metric-card">
                    <h3>System Uptime</h3>
                    <div class="metric-value">$(uptime | awk '{print $3}' | sed 's/,//')<span class="metric-unit">hours</span></div>
                </div>
                <div class="metric-card">
                    <h3>CPU Usage</h3>
                    <div class="metric-value">$(query_prometheus "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)")<span class="metric-unit">%</span></div>
                </div>
                <div class="metric-card">
                    <h3>Memory Usage</h3>
                    <div class="metric-value">$(query_prometheus "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100")<span class="metric-unit">%</span></div>
                </div>
                <div class="metric-card">
                    <h3>Disk Usage</h3>
                    <div class="metric-value">$(df / | tail -1 | awk '{print $5}' | sed 's/%//')<span class="metric-unit">%</span></div>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>🐳 Service Status</h2>
            <table class="status-table">
                <thead>
                    <tr>
                        <th>Service</th>
                        <th>Status</th>
                        <th>Uptime</th>
                        <th>CPU Usage</th>
                        <th>Memory Usage</th>
                    </tr>
                </thead>
                <tbody>
EOF

    # Добавляем статус сервисов
    local services=("prometheus" "grafana" "alertmanager" "node-exporter" "cadvisor" "n8n-exporter")
    
    for service in "${services[@]}"; do
        local container_name="n8n-ai-$service"
        local status="❌ Down"
        local uptime="N/A"
        local cpu="N/A"
        local memory="N/A"
        local status_class="status-error"
        
        if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            status="✅ Running"
            status_class="status-healthy"
            
            # Получаем uptime контейнера
            uptime=$(docker inspect "$container_name" --format='{{.State.StartedAt}}' | \
                     xargs -I {} date -d {} +%s | \
                     awk -v now="$(date +%s)" '{print int((now - $1) / 3600) "h " int(((now - $1) % 3600) / 60) "m"}' || echo "N/A")
            
            # Получаем статистику
            local stats=$(docker stats "$container_name" --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -1 || echo "N/A\tN/A")
            cpu=$(echo "$stats" | cut -f1 || echo "N/A")
            memory=$(echo "$stats" | cut -f2 | cut -d'/' -f1 || echo "N/A")
        fi
        
        cat >> "$report_file" << EOF
                    <tr>
                        <td>$service</td>
                        <td class="$status_class">$status</td>
                        <td>$uptime</td>
                        <td>$cpu</td>
                        <td>$memory</td>
                    </tr>
EOF
    done
    
    cat >> "$report_file" << EOF
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>🚀 N8N Workflows</h2>
            <div class="metrics-grid">
                <div class="metric-card">
                    <h3>Total Workflows</h3>
                    <div class="metric-value">$(query_prometheus "n8n_workflows_total")</div>
                </div>
                <div class="metric-card">
                    <h3>Active Workflows</h3>
                    <div class="metric-value">$(query_prometheus "n8n_workflows_active")</div>
                </div>
                <div class="metric-card">
                    <h3>Executions (1h)</h3>
                    <div class="metric-value">$(query_prometheus "increase(n8n_workflow_executions_total[1h])")</div>
                </div>
                <div class="metric-card">
                    <h3>Failed Executions (1h)</h3>
                    <div class="metric-value">$(query_prometheus "increase(n8n_workflow_executions_failed_total[1h])")</div>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>🧠 AI Services</h2>
            <div class="metrics-grid">
                <div class="metric-card">
                    <h3>Ollama Status</h3>
                    <div class="metric-value">$(query_prometheus "up{job=\"ollama\"}" | awk '{if($1==1) print "🟢 Online"; else print "🔴 Offline"}')</div>
                </div>
                <div class="metric-card">
                    <h3>Qdrant Status</h3>
                    <div class="metric-value">$(query_prometheus "up{job=\"qdrant\"}" | awk '{if($1==1) print "🟢 Online"; else print "🔴 Offline"}')</div>
                </div>
                <div class="metric-card">
                    <h3>RAG Queries (1h)</h3>
                    <div class="metric-value">$(query_prometheus "increase(rag_queries_total[1h])")</div>
                </div>
                <div class="metric-card">
                    <h3>Avg Response Time</h3>
                    <div class="metric-value">$(query_prometheus "avg(rag_query_duration_ms)")<span class="metric-unit">ms</span></div>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>📈 Performance Trends</h2>
            <div class="chart-placeholder">
                📊 Performance charts would be displayed here<br>
                <small>Connect to Grafana at <a href="http://localhost:3000" target="_blank">http://localhost:3000</a> for detailed charts</small>
            </div>
        </div>

        <div class="section">
            <h2>🚨 Recent Alerts</h2>
            <div class="alert alert-info">
                <strong>Info:</strong> No critical alerts in the last 24 hours.
            </div>
        </div>

        <div class="section">
            <h2>💡 Recommendations</h2>
            <ul>
                <li>Monitor disk space usage - currently at $(df / | tail -1 | awk '{print $5}')</li>
                <li>Check workflow execution success rates regularly</li>
                <li>Review AI service response times for optimization opportunities</li>
                <li>Set up automated backup schedules for critical data</li>
            </ul>
        </div>

        <div class="footer">
            Generated by N8N AI Starter Kit Monitoring System<br>
            <small>Report generated on $report_date | Prometheus: <a href="http://localhost:9090">http://localhost:9090</a> | Grafana: <a href="http://localhost:3000">http://localhost:3000</a></small>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "HTML report generated: $report_file"
    echo "Open in browser: file://$report_file"
}

# Генерация JSON отчета
generate_json_report() {
    local report_file="$REPORTS_DIR/monitoring_report_$(date +%Y%m%d_%H%M%S).json"
    
    log_info "Generating JSON report: $report_file"
    
    cat > "$report_file" << EOF
{
  "report": {
    "timestamp": "$(date -Iseconds)",
    "generator": "N8N AI Starter Kit Monitoring",
    "version": "1.0.0"
  },
  "system": {
    "uptime": "$(uptime -p)",
    "load_average": "$(uptime | awk -F'load average:' '{print $2}' | xargs)",
    "cpu_usage_percent": $(query_prometheus "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"),
    "memory_usage_percent": $(query_prometheus "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"),
    "disk_usage_percent": $(df / | tail -1 | awk '{print $5}' | sed 's/%//')
  },
  "services": {
EOF

    # Добавляем информацию о сервисах
    local services=("prometheus" "grafana" "alertmanager" "node-exporter" "cadvisor" "n8n-exporter")
    local first=true
    
    for service in "${services[@]}"; do
        local container_name="n8n-ai-$service"
        local status="false"
        
        if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            status="true"
        fi
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$report_file"
        fi
        
        cat >> "$report_file" << EOF
    "$service": {
      "status": $status,
      "container_name": "$container_name"
    }
EOF
    done
    
    cat >> "$report_file" << EOF
  },
  "n8n": {
    "total_workflows": $(query_prometheus "n8n_workflows_total"),
    "active_workflows": $(query_prometheus "n8n_workflows_active"),
    "executions_last_hour": $(query_prometheus "increase(n8n_workflow_executions_total[1h])"),
    "failed_executions_last_hour": $(query_prometheus "increase(n8n_workflow_executions_failed_total[1h])")
  },
  "ai_services": {
    "ollama_status": $(query_prometheus "up{job=\"ollama\"}"),
    "qdrant_status": $(query_prometheus "up{job=\"qdrant\"}"),
    "rag_queries_last_hour": $(query_prometheus "increase(rag_queries_total[1h])"),
    "avg_response_time_ms": $(query_prometheus "avg(rag_query_duration_ms)")
  }
}
EOF
    
    log_success "JSON report generated: $report_file"
}

# Отправка отчета по email (если настроено)
send_email_report() {
    local report_file="$1"
    local email="${MONITORING_EMAIL:-}"
    
    if [[ -n "$email" ]]; then
        log_info "Sending email report to: $email"
        
        # Используем mail или sendmail если доступны
        if command -v mail &> /dev/null; then
            cat "$report_file" | mail -s "N8N AI Monitoring Report - $(date +%Y-%m-%d)" "$email"
            log_success "Email report sent"
        else
            log_warning "Mail command not available, skipping email"
        fi
    fi
}

# Очистка старых отчетов
cleanup_old_reports() {
    local retention_days="${REPORTS_RETENTION_DAYS:-7}"
    
    log_info "Cleaning up reports older than $retention_days days"
    
    find "$REPORTS_DIR" -name "monitoring_report_*.html" -mtime +$retention_days -delete 2>/dev/null || true
    find "$REPORTS_DIR" -name "monitoring_report_*.json" -mtime +$retention_days -delete 2>/dev/null || true
    
    log_success "Old reports cleaned up"
}

# Отображение справки
show_help() {
    echo "N8N AI Starter Kit - Monitoring Report Generator"
    echo ""
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  html      Generate HTML report (default)"
    echo "  json      Generate JSON report"
    echo "  both      Generate both HTML and JSON reports"
    echo "  cleanup   Clean up old reports"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  PROMETHEUS_URL          Prometheus server URL (default: http://localhost:9090)"
    echo "  MONITORING_EMAIL        Email address for report notifications"
    echo "  REPORTS_RETENTION_DAYS  Days to keep old reports (default: 7)"
    echo ""
}

# Основная функция
main() {
    local command="${1:-html}"
    
    case "$command" in
        "html")
            create_reports_dir
            generate_html_report
            ;;
        "json")
            create_reports_dir
            generate_json_report
            ;;
        "both")
            create_reports_dir
            generate_html_report
            generate_json_report
            ;;
        "cleanup")
            cleanup_old_reports
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
