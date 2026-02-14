#!/bin/bash

# Environment Configuration Loader
# This script loads environment-specific configurations
# Version: 1.0
# Author: AWS DevOps Pipeline

set -euo pipefail
IFS=$'\n\t'

# Configuration variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ENVIRONMENTS_DIR="$PROJECT_ROOT/environments"
readonly LOG_FILE="/var/log/environment-config.log"

# Default environment if not specified
DEFAULT_ENV="dev"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

# Function to validate environment name
validate_environment() {
    local env_name="$1"
    local valid_envs=("dev" "staging" "prod")
    
    if [[ ! " ${valid_envs[@]} " =~ " ${env_name} " ]]; then
        log_error "Invalid environment: $env_name. Valid environments: ${valid_envs[*]}"
        exit 1
    fi
}

# Function to check if environment file exists
check_environment_file() {
    local env_name="$1"
    local env_file="$ENVIRONMENTS_DIR/${env_name}.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        exit 1
    fi
    
    log_info "Environment file found: $env_file"
}

# Function to load environment configuration
load_environment_config() {
    local env_name="$1"
    local env_file="$ENVIRONMENTS_DIR/${env_name}.env"
    
    log_info "Loading environment configuration for: $env_name"
    
    # Export all variables from the environment file
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
    
    log_info "Environment configuration loaded successfully"
}

# Function to display loaded configuration
display_configuration() {
    local env_name="$1"
    
    log_info "=== Configuration Summary for $env_name ==="
    log_info "APP_ENV: ${APP_ENV:-not_set}"
    log_info "APP_DEBUG: ${APP_DEBUG:-not_set}"
    log_info "NGINX_WORKER_PROCESSES: ${NGINX_WORKER_PROCESSES:-not_set}"
    log_info "SECURITY_HEADERS_ENABLED: ${SECURITY_HEADERS_ENABLED:-not_set}"
    log_info "RATE_LIMITING_ENABLED: ${RATE_LIMITING_ENABLED:-not_set}"
    log_info "MONITORING_ENABLED: ${MONITORING_ENABLED:-not_set}"
}

# Function to apply Nginx configuration based on environment
apply_nginx_config() {
    local env_name="$1"
    
    log_info "Applying Nginx configuration for $env_name environment"
    
    # Create Nginx configuration file from environment variables
    local nginx_config="/etc/nginx/conf.d/environment.conf"
    
    cat > "$nginx_config" << EOF
# Environment-specific Nginx configuration
# Generated for environment: $env_name
# Generated on: $(date)

# Worker processes
worker_processes ${NGINX_WORKER_PROCESSES:-auto};

# Worker connections
events {
    worker_connections ${NGINX_WORKER_CONNECTIONS:-1024};
}

# Keepalive timeout
keepalive_timeout ${NGINX_KEEPALIVE_TIMEOUT:-65};

# Gzip compression
gzip ${GZIP_COMPRESSION_ENABLED:-off};
gzip_comp_level 6;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

# Rate limiting (if enabled)
EOF

    if [[ "${RATE_LIMITING_ENABLED:-false}" == "true" ]]; then
        cat >> "$nginx_config" << EOF
limit_req_zone \$binary_remote_addr zone=api:10m rate=${RATE_LIMIT_REQUESTS_PER_SECOND:-10}r/s;
limit_req zone=api burst=20 nodelay;
EOF
    fi
    
    # Test Nginx configuration
    if nginx -t; then
        log_info "Nginx configuration is valid"
    else
        log_error "Nginx configuration is invalid"
        exit 1
    fi
}

# Function to set up environment-specific logging
setup_logging() {
    local env_name="$1"
    local log_level="${APP_LOG_LEVEL:-info}"
    
    log_info "Setting up logging for $env_name environment with level: $log_level"
    
    # Create log directories
    mkdir -p /var/log/nginx
    mkdir -p /var/log/application
    
    # Set log levels based on environment
    case "$env_name" in
        "dev")
            echo "log_level debug;" > /etc/nginx/conf.d/logging.conf
            ;;
        "staging")
            echo "log_level info;" > /etc/nginx/conf.d/logging.conf
            ;;
        "prod")
            echo "log_level error;" > /etc/nginx/conf.d/logging.conf
            ;;
    esac
}

# Function to validate required variables
validate_required_variables() {
    local env_name="$1"
    local required_vars=("APP_ENV" "NGINX_WORKER_PROCESSES")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required variables: ${missing_vars[*]}"
        exit 1
    fi
    
    log_info "All required variables are set"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT]"
    echo "ENVIRONMENT: dev, staging, or prod (default: dev)"
    echo ""
    echo "Examples:"
    echo "  $0 dev      # Load development configuration"
    echo "  $0 staging  # Load staging configuration"
    echo "  $0 prod     # Load production configuration"
}

# Main execution
main() {
    local env_name="${1:-$DEFAULT_ENV}"
    
    log_info "=== Environment Configuration Loader Started ==="
    log_info "Environment: $env_name"
    
    # Validate inputs
    validate_environment "$env_name"
    check_environment_file "$env_name"
    
    # Load configuration
    load_environment_config "$env_name"
    validate_required_variables "$env_name"
    
    # Apply configurations
    apply_nginx_config "$env_name"
    setup_logging "$env_name"
    
    # Display summary
    display_configuration "$env_name"
    
    log_info "Environment configuration completed successfully!"
    log_info "=== Environment Configuration Loader Completed ==="
}

# Handle command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    main "$@"
fi
