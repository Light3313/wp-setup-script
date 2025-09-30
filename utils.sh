#!/bin/bash

# createNewSite Utilities Module
# Version: 1.0.0
# Author: Light
# License: MIT

# Source configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Print colored output functions
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}Info: $1${NC}"
}

print_debug() {
    echo -e "${PURPLE}Debug: $1${NC}"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

# Print separator line
print_separator() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    echo ""
    printf '%*s\n' "$cols" '' | tr ' ' '-'
}

# Print banner
print_banner() {
    print_separator
    print_header "$CONFIG_SCRIPT_NAME v$CONFIG_SCRIPT_VERSION"
    print_header "Author: $CONFIG_SCRIPT_AUTHOR | License: $CONFIG_SCRIPT_LICENSE"
    print_separator
}

# Show help
show_help() {
    echo "$HELP_TEXT"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "$ERROR_ROOT_REQUIRED"
        exit 1
    fi
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check if Apache modules are enabled
    if ! apache2ctl -M 2>/dev/null | grep -q "rewrite_module"; then
        missing_deps+=("apache2 mod_rewrite")
    fi
    
    # Check if MySQL is running
    if ! systemctl is-active --quiet mysql && ! systemctl is-active --quiet mariadb; then
        missing_deps+=("mysql/mariadb service not running")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "$ERROR_MISSING_DEPS: ${missing_deps[*]}"
        echo ""
        echo "Please install missing packages:"
        echo "  sudo apt update"
        echo "  sudo apt install apache2 mysql-server"
        echo "  sudo a2enmod rewrite"
        echo "  sudo systemctl start mysql"
        echo ""
        echo "Install WP-CLI:"
        echo "  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
        echo "  chmod +x wp-cli.phar"
        echo "  sudo mv wp-cli.phar /usr/local/bin/wp"
        exit 1
    fi
}

# Create temporary file safely
create_temp_file() {
    local prefix="${1:-temp}"
    mktemp "/tmp/${prefix}.XXXXXX" 2>/dev/null || mktemp "/tmp/${prefix}.XXXXXX"
}

# Backup file safely
backup_file() {
    local file="$1"
    local backup_suffix="${2:-.backup}"
    
    if [[ -f "$file" ]]; then
        cp "$file" "${file}${backup_suffix}"
        print_info "Backed up $file to ${file}${backup_suffix}"
    fi
}

# Restore file from backup
restore_file() {
    local file="$1"
    local backup_suffix="${2:-.backup}"
    
    if [[ -f "${file}${backup_suffix}" ]]; then
        cp "${file}${backup_suffix}" "$file"
        print_info "Restored $file from ${file}${backup_suffix}"
    fi
}

# Clean up temporary files
cleanup_temp_files() {
    local temp_files=("$@")
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
        fi
    done
}

# Log message with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            print_error "[$timestamp] $message"
            ;;
        "SUCCESS")
            print_success "[$timestamp] $message"
            ;;
        "WARNING")
            print_warning "[$timestamp] $message"
            ;;
        "INFO")
            print_info "[$timestamp] $message"
            ;;
        "DEBUG")
            print_debug "[$timestamp] $message"
            ;;
        *)
            echo "[$timestamp] $message"
            ;;
    esac
}

# Confirm action with user
confirm_action() {
    local message="$1"
    local default="${2:-no}"
    
    if [[ "$default" == "yes" ]]; then
        read -p "$message [Y/n]: " -r response
        [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]
    else
        read -p "$message [y/N]: " -r response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Get system information
get_system_info() {
    echo "System Information:"
    echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -s)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Apache Version: $(apache2 -v 2>/dev/null | head -n1 || echo 'Not available')"
    echo "  MySQL Version: $(mysql --version 2>/dev/null || echo 'Not available')"
    echo "  WP-CLI Version: $(wp --version 2>/dev/null || echo 'Not available')"
}

# Validate file permissions
validate_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    
    if [[ -f "$file" ]]; then
        local actual_perms
        actual_perms=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
        if [[ "$actual_perms" != "$expected_perms" ]]; then
            print_warning "File $file has permissions $actual_perms, expected $expected_perms"
            return 1
        fi
    fi
    return 0
}

# Set file permissions safely
set_file_permissions() {
    local file="$1"
    local permissions="$2"
    local owner="${3:-www-data:www-data}"
    
    if [[ -e "$file" ]]; then
        chown "$owner" "$file" 2>/dev/null || true
        chmod "$permissions" "$file" 2>/dev/null || true
    fi
}

# Recursively set directory permissions
set_directory_permissions() {
    local dir="$1"
    local dir_perms="${2:-755}"
    local file_perms="${3:-644}"
    local owner="${4:-www-data:www-data}"
    
    if [[ -d "$dir" ]]; then
        chown -R "$owner" "$dir" 2>/dev/null || true
        find "$dir" -type d -exec chmod "$dir_perms" {} \; 2>/dev/null || true
        find "$dir" -type f -exec chmod "$file_perms" {} \; 2>/dev/null || true
    fi
}

# Check disk space
check_disk_space() {
    local path="$1"
    local required_mb="${2:-100}"
    
    local available_mb
    available_mb=$(df "$path" | awk 'NR==2 {print int($4/1024)}')
    
    if [[ "$available_mb" -lt "$required_mb" ]]; then
        print_warning "Low disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    
    return 0
}

# Generate random password
generate_random_password() {
    local length="${1:-12}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Generate random database name
generate_random_db_name() {
    local prefix="${1:-wp}"
    echo "${prefix}_$(openssl rand -hex 4)"
}

# Generate random username
generate_random_username() {
    local prefix="${1:-user}"
    echo "${prefix}_$(openssl rand -hex 4)"
}

# Check if port is available
check_port_available() {
    local port="$1"
    ! netstat -tuln 2>/dev/null | grep -q ":$port "
}

# Get available port
get_available_port() {
    local start_port="${1:-8080}"
    local end_port="${2:-8090}"
    
    for port in $(seq "$start_port" "$end_port"); do
        if check_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    return 1
}

# Wait for service to be ready
wait_for_service() {
    local service="$1"
    local max_wait="${2:-30}"
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 1
        ((wait_time++))
    done
    
    return 1
}

# Test network connectivity
test_network_connectivity() {
    local host="${1:-google.com}"
    local port="${2:-80}"
    
    timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null
}

# Get external IP
get_external_ip() {
    curl -s --max-time 5 ifconfig.me 2>/dev/null || \
    curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || \
    curl -s --max-time 5 icanhazip.com 2>/dev/null || \
    echo "Unable to determine external IP"
}

# Format bytes to human readable
format_bytes() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $bytes -ge 1024 && $unit -lt 4 ]]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes}${units[$unit]}"
}

# Get file size
get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size
        size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
        format_bytes "$size"
    else
        echo "0B"
    fi
}

# Get directory size
get_directory_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        local size
        size=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo "0")
        format_bytes "$size"
    else
        echo "0B"
    fi
}

# Count files in directory
count_files() {
    local dir="$1"
    local pattern="${2:-*}"
    
    if [[ -d "$dir" ]]; then
        find "$dir" -name "$pattern" -type f | wc -l
    else
        echo "0"
    fi
}

# Count directories
count_directories() {
    local dir="$1"
    
    if [[ -d "$dir" ]]; then
        find "$dir" -type d | wc -l
    else
        echo "0"
    fi
}

# Check if string is empty or whitespace
is_empty() {
    local str="$1"
    [[ -z "${str// }" ]]
}

# Trim whitespace
trim() {
    local str="$1"
    echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Convert to lowercase
to_lowercase() {
    local str="$1"
    echo "$str" | tr '[:upper:]' '[:lower:]'
}

# Convert to uppercase
to_uppercase() {
    local str="$1"
    echo "$str" | tr '[:lower:]' '[:upper:]'
}

# Escape special characters for sed
escape_sed() {
    local str="$1"
    echo "$str" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Escape special characters for grep
escape_grep() {
    local str="$1"
    echo "$str" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Check if running in interactive mode
is_interactive() {
    [[ -t 0 && -t 1 ]]
}

# Check if running in CI/CD environment
is_ci_environment() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${TRAVIS:-}" ]] || [[ -n "${JENKINS_URL:-}" ]]
}

# Get script directory
get_script_dir() {
    dirname "$(readlink -f "${BASH_SOURCE[1]}")"
}

# Get script name
get_script_name() {
    basename "$(readlink -f "${BASH_SOURCE[1]}")"
}

# Check if script is being sourced
is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# Export all functions for use in other scripts
export -f print_error print_success print_warning print_info print_debug print_header
export -f print_separator print_banner show_help check_root check_dependencies
export -f create_temp_file backup_file restore_file cleanup_temp_files
export -f log_message confirm_action command_exists get_system_info
export -f validate_file_permissions set_file_permissions set_directory_permissions
export -f check_disk_space generate_random_password generate_random_db_name generate_random_username
export -f check_port_available get_available_port wait_for_service test_network_connectivity
export -f get_external_ip format_bytes get_file_size get_directory_size
export -f count_files count_directories is_empty trim to_lowercase to_uppercase
export -f escape_sed escape_grep is_interactive is_ci_environment
export -f get_script_dir get_script_name is_sourced
