#!/bin/bash

# Deployment Validation Script
# Performs end-to-end verification of the deployed web application
# Lifecycle Hook: ValidateService (runorder: 1)

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/deployment-validation.log"
readonly MAX_RETRIES=10
readonly RETRY_INTERVAL=2
readonly TARGET_URL="http://127.0.0.1"

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

check_service_status() {
    log_info "1. Verifying Nginx service status..."
    
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet nginx; then
            log_info "✅ Nginx service is running."
        else
            log_error "❌ Nginx service is NOT running."
            systemctl status nginx --no-pager | tee -a "$LOG_FILE" || true
            exit 1
        fi
    elif command -v service &>/dev/null; then
        if service nginx status &>/dev/null; then
            log_info "✅ Nginx service is active."
        else
            log_error "❌ Nginx service is NOT active."
            exit 1
        fi
    fi
}

check_file_system() {
    log_info "2. Verifying web assets in /var/www/html..."
    
    if [[ ! -f "/var/www/html/index.html" ]]; then
        log_error "❌ index.html not found in /var/www/html"
        exit 1
    fi
    
    if [[ ! -r "/var/www/html/index.html" ]]; then
        log_error "❌ /var/www/html/index.html is not readable"
        exit 1
    fi
    
    log_info "✅ /var/www/html/index.html is present and readable."
}

check_http_response() {
    log_info "3. Testing HTTP availability and response code at ${TARGET_URL}..."
    local success=false
    local http_code=""

    for attempt in $(seq 1 $MAX_RETRIES); do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$TARGET_URL" || echo "000")
        
        if [[ "$http_code" == "200" ]]; then
            log_info "✅ HTTP 200 OK received on attempt $attempt"
            success=true
            break
        else
            log_warning "Attempt $attempt/$MAX_RETRIES: Received HTTP status code '$http_code'. Retrying in ${RETRY_INTERVAL}s..."
            sleep "$RETRY_INTERVAL"
        fi
    done

    if [[ "$success" != true ]]; then
        log_error "❌ HTTP health check failed. Final HTTP status code: $http_code"
        exit 1
    fi
}

check_content_integrity() {
    log_info "4. Testing HTML content integrity..."
    local content
    content=$(curl -s --connect-timeout 5 "$TARGET_URL")
    
    if echo "$content" | grep -qi "<html"; then
        log_info "✅ HTML structure validated in response."
    else
        log_error "❌ HTML tags not found in HTTP response."
        exit 1
    fi
}

check_security_headers() {
    log_info "5. Verifying security headers..."
    local headers
    headers=$(curl -s -I --connect-timeout 5 "$TARGET_URL")
    
    if echo "$headers" | grep -qi "X-Content-Type-Options"; then
        log_info "✅ Security header 'X-Content-Type-Options' detected."
    else
        log_warning "Security header 'X-Content-Type-Options' not found in response."
    fi

    if echo "$headers" | grep -qi "X-Frame-Options"; then
        log_info "✅ Security header 'X-Frame-Options' detected."
    else
        log_warning "Security header 'X-Frame-Options' not found in response."
    fi
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    log_info "=== DEPLOYMENT VALIDATION (VALIDATESERVICE) STARTED ==="
    
    check_service_status
    check_file_system
    check_http_response
    check_content_integrity
    check_security_headers
    
    log_info "=== ALL DEPLOYMENT VALIDATION CHECKS PASSED SUCCESSFULLY ==="
}

main "$@"
