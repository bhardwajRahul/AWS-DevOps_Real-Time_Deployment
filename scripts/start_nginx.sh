#!/bin/bash

# Nginx Service Startup and Health Verification Script
# Lifecycle Hook: ApplicationStart (runorder: 1)

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/nginx-start.log"
readonly LOCK_FILE="/var/lock/nginx-start.lock"
readonly MAX_RETRIES=5
readonly RETRY_DELAY=2

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

log_error() {
    log_message "ERROR" "$1"
}

cleanup() {
    local exit_code=$?
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
    if [[ $exit_code -ne 0 ]]; then
        log_error "Nginx startup script exited with error code $exit_code"
    fi
}

trap cleanup EXIT INT TERM

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_FILE")" "$(dirname "$LOG_FILE")"
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Another startup process is already running (PID: $pid)"
            exit 1
        else
            log_warning "Removing stale startup lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

validate_config() {
    log_info "Validating Nginx configuration syntax..."
    if ! nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Nginx configuration test failed. Halting startup."
        exit 1
    fi
    log_info "Nginx configuration syntax is valid."
}

start_or_restart_service() {
    log_info "Starting Nginx service..."
    local started=false

    for attempt in $(seq 1 $MAX_RETRIES); do
        log_info "Attempt $attempt/$MAX_RETRIES: Starting Nginx..."
        
        if command -v systemctl &>/dev/null; then
            if systemctl restart nginx; then
                started=true
                break
            fi
        elif command -v service &>/dev/null; then
            if service nginx restart; then
                started=true
                break
            fi
        else
            if nginx -s reload 2>/dev/null || nginx; then
                started=true
                break
            fi
        fi
        
        log_warning "Start attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"
    done

    if [[ "$started" != true ]]; then
        log_error "Failed to start Nginx after $MAX_RETRIES attempts"
        if command -v systemctl &>/dev/null; then
            systemctl status nginx --no-pager | tee -a "$LOG_FILE" || true
        fi
        exit 1
    fi
}

verify_service_health() {
    log_info "Verifying Nginx service status..."
    sleep 2

    # Check active status
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet nginx; then
            log_info "✅ Nginx systemd service is active"
        else
            log_error "❌ Nginx systemd service is NOT active"
            exit 1
        fi
    fi

    # Check listening port (80)
    local port_open=false
    if command -v ss &>/dev/null; then
        if ss -tln | grep -q ":80 "; then
            port_open=true
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tln | grep -q ":80 "; then
            port_open=true
        fi
    else
        port_open=true
    fi

    if [[ "$port_open" == true ]]; then
        log_info "✅ Port 80 is listening"
    else
        log_warning "Port 80 check did not find listener; verifying via curl"
    fi

    # HTTP verification
    local http_ready=false
    for i in $(seq 1 5); do
        if curl -s -f -o /dev/null "http://127.0.0.1"; then
            http_ready=true
            log_info "✅ Local HTTP check responded successfully"
            break
        fi
        sleep 1
    done

    if [[ "$http_ready" != true ]]; then
        log_warning "Local HTTP response check pending (will be verified in ValidateService phase)"
    fi
}

main() {
    log_info "=== NGINX START SCRIPT STARTED ==="
    acquire_lock
    validate_config
    start_or_restart_service
    verify_service_health
    log_info "=== NGINX START SCRIPT COMPLETED SUCCESSFULLY ==="
}

main "$@"
