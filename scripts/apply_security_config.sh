#!/bin/bash

# Apply Security Configuration Script
# Copies Nginx security headers and applies hardening
# Lifecycle Hook: AfterInstall (runorder: 2)

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/apply-security-config.log"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly SECURITY_CONF="${PROJECT_ROOT}/nginx-security.conf"
readonly NGINX_CONF_DIR="/etc/nginx/conf.d"
readonly WEB_ROOT="/var/www/html"

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

apply_nginx_security_conf() {
    log_info "Applying Nginx security configuration..."
    
    mkdir -p "$NGINX_CONF_DIR"
    
    if [[ -f "$SECURITY_CONF" ]]; then
        cp -f "$SECURITY_CONF" "${NGINX_CONF_DIR}/security.conf"
        chmod 644 "${NGINX_CONF_DIR}/security.conf"
        log_info "Security configuration copied to ${NGINX_CONF_DIR}/security.conf"
    else
        log_warning "Security config file not found at ${SECURITY_CONF}"
    fi

    # Create / update optimized default server block
    local default_site_conf="/etc/nginx/conf.d/app.conf"
    
    cat > "$default_site_conf" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    root /var/www/html;
    index index.html index.htm;

    # Rate limiting & connection limiting
    limit_req zone=req_limit burst=30 nodelay;
    limit_conn addr_limit 20;

    # Allow only safe HTTP methods
    if ($request_method !~ ^(GET|HEAD|POST|OPTIONS)$ ) {
        return 405;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    # Block access to hidden files (.git, .env, etc.)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block access to sensitive scripts and configurations
    location ~* \.(sh|conf|env|bak|sql|log|yml|yaml)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF
    chmod 644 "$default_site_conf"
    log_info "App server configuration created at ${default_site_conf}"
}

harden_permissions() {
    log_info "Hardening file and directory permissions..."
    
    # Determine web server user
    local web_user="www-data"
    if ! id "$web_user" &>/dev/null; then
        if id "nginx" &>/dev/null; then
            web_user="nginx"
        else
            web_user="root"
        fi
    fi
    
    if [[ -d "$WEB_ROOT" ]]; then
        chown -R "${web_user}:${web_user}" "$WEB_ROOT"
        find "$WEB_ROOT" -type d -exec chmod 755 {} +
        find "$WEB_ROOT" -type f -exec chmod 644 {} +
        find "$WEB_ROOT" -name "*.sh" -exec chmod 750 {} +
        log_info "Permissions hardened for ${WEB_ROOT} (User: ${web_user})"
    fi
}

validate_nginx() {
    log_info "Testing Nginx configuration syntax..."
    if command -v nginx &>/dev/null; then
        if nginx -t; then
            log_info "Nginx configuration syntax is OK"
        else
            log_error "Nginx configuration test failed"
            exit 1
        fi
    fi
}

main() {
    log_info "=== APPLY SECURITY CONFIGURATION STARTED ==="
    mkdir -p "$(dirname "$LOG_FILE")"
    apply_nginx_security_conf
    harden_permissions
    validate_nginx
    log_info "=== APPLY SECURITY CONFIGURATION COMPLETED ==="
}

main "$@"
