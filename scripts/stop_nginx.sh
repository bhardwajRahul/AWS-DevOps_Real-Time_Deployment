#!/bin/bash

# Application Stop Script
# Gracefully stops or pauses Nginx prior to file replacement
# Lifecycle Hook: ApplicationStop (runorder: 1)

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/nginx-stop.log"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    log_info "=== APPLICATION STOP HOOK STARTED ==="
    
    if command -v systemctl &>/dev/null && systemctl is-active --quiet nginx; then
        log_info "Stopping Nginx service gracefully..."
        if systemctl stop nginx; then
            log_info "Nginx stopped successfully"
        else
            log_warning "Failed to stop Nginx via systemctl; attempting reload"
            systemctl reload nginx || true
        fi
    elif command -v service &>/dev/null && service nginx status &>/dev/null; then
        log_info "Stopping Nginx via service command..."
        service nginx stop || true
    else
        log_info "Nginx is not running or not installed yet. Skipping stop."
    fi
    
    log_info "=== APPLICATION STOP HOOK COMPLETED ==="
}

main "$@"
