#!/bin/bash

# Environment Configuration Loader
# Loads environment-specific variables and generates compliant Nginx configuration
# Usage: ./scripts/load_environment_config.sh [dev|staging|prod]

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ENVIRONMENTS_DIR="$PROJECT_ROOT/environments"
readonly LOG_FILE="/var/log/environment-config.log"
readonly DEFAULT_ENV="dev"

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

validate_environment() {
    local env_name="$1"
    case "$env_name" in
        dev|development)
            ENV_NAME="dev"
            ;;
        staging|stage|preprod)
            ENV_NAME="staging"
            ;;
        prod|production)
            ENV_NAME="prod"
            ;;
        *)
            log_error "Invalid environment '$env_name'. Valid options: dev, staging, prod"
            exit 1
            ;;
    esac
}

load_environment_config() {
    local env_file="${ENVIRONMENTS_DIR}/${ENV_NAME}.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        exit 1
    fi
    
    log_info "Loading configuration from: $env_file"
    
    # Export variables safely
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
    
    log_info "Environment configuration for '${ENV_NAME}' loaded successfully."
}

apply_nginx_config() {
    local nginx_conf_dir="/etc/nginx/conf.d"
    local env_conf_file="${nginx_conf_dir}/environment.conf"
    local logging_conf_file="${nginx_conf_dir}/logging.conf"
    
    # If Nginx directory doesn't exist (e.g. running in testing/CI), write to local scratch or skip
    if [[ ! -d "$nginx_conf_dir" ]]; then
        log_warning "Directory ${nginx_conf_dir} not found. Skipping live Nginx conf generation."
        return 0
    fi
    
    log_info "Generating environment-specific Nginx settings..."
    
    # HTTP-context valid environment settings
    cat > "$env_conf_file" << EOF
# Auto-generated Nginx Environment Settings: ${ENV_NAME}
# Generated: $(date -u)

# Connection & Keepalive
keepalive_timeout ${NGINX_KEEPALIVE_TIMEOUT:-65};

# Compression settings
gzip ${GZIP_COMPRESSION_ENABLED:-on};
gzip_vary on;
gzip_comp_level 6;
EOF
    chmod 644 "$env_conf_file"

    # Set valid error log level
    local log_level="error"
    case "${APP_LOG_LEVEL:-error}" in
        debug) log_level="debug" ;;
        info) log_level="info" ;;
        notice) log_level="notice" ;;
        warn|warning) log_level="warn" ;;
        error) log_level="error" ;;
        *) log_level="error" ;;
    esac

    cat > "$logging_conf_file" << EOF
# Auto-generated Nginx Logging Settings: ${ENV_NAME}
error_log /var/log/nginx/error.log ${log_level};
EOF
    chmod 644 "$logging_conf_file"

    if command -v nginx &>/dev/null; then
        if nginx -t; then
            log_info "Nginx environment configuration validated successfully."
        else
            log_error "Nginx configuration validation failed."
            exit 1
        fi
    fi
}

display_summary() {
    log_info "=== Environment Configuration Summary ==="
    log_info "Target Environment : ${ENV_NAME}"
    log_info "APP_ENV            : ${APP_ENV:-unknown}"
    log_info "APP_DEBUG          : ${APP_DEBUG:-false}"
    log_info "APP_LOG_LEVEL      : ${APP_LOG_LEVEL:-info}"
    log_info "SECURITY_HEADERS   : ${SECURITY_HEADERS_ENABLED:-false}"
    log_info "RATE_LIMITING      : ${RATE_LIMITING_ENABLED:-false}"
}

show_usage() {
    echo "Usage: $0 [dev|staging|prod]"
    echo ""
    echo "Examples:"
    echo "  $0 dev       # Load development profile"
    echo "  $0 staging   # Load staging profile"
    echo "  $0 prod      # Load production profile"
}

main() {
    local target_env="${1:-$DEFAULT_ENV}"
    
    if [[ "$target_env" == "-h" || "$target_env" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    mkdir -p "$(dirname "$LOG_FILE")"
    log_info "=== ENVIRONMENT CONFIG LOADER STARTED ==="
    validate_environment "$target_env"
    load_environment_config
    apply_nginx_config
    display_summary
    log_info "=== ENVIRONMENT CONFIG LOADER COMPLETED ==="
}

main "$@"
