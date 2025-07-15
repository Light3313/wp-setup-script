#!/bin/bash

# createNewSite - Automated WordPress Site Creator/Remover
# Version: 1.0.0
# Author: Light
# License: MIT

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_NAME="createNewSite"
readonly SCRIPT_VERSION="1.0.0"
readonly APACHE_SITES_DIR="/etc/apache2/sites-available"
readonly APACHE_ENABLED_DIR="/etc/apache2/sites-enabled"
readonly WEB_ROOT="/var/www/html"
readonly HOSTS_FILE="/etc/hosts"
readonly APACHE_LOG_DIR="/var/log/apache2"

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m' # No Color

# Global variables for cleanup
SITE_NAME=""
SITE_DIR=""
DB_NAME=""
DB_USER=""
CLEANUP_NEEDED=false

# Reserved names that shouldn't be used as site names
readonly RESERVED_NAMES=(
    "localhost" "www" "admin" "root" "mysql" "apache" "api"
)

# Print colored output
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

print_separator() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    echo ""
    printf '%*s\n' "$cols" '' | tr ' ' '-'
}

# Show help
show_help() {
    cat <<EOF
$SCRIPT_NAME - Automated WordPress Site Creator/Remover v$SCRIPT_VERSION

DESCRIPTION:
  This script creates or removes a local WordPress site with Apache and MySQL integration.
  It sets up the site directory, database, Apache virtual host, hosts entry, and WordPress installation.

USAGE:
  sudo $SCRIPT_NAME <site-name> <admin-name> <admin-password> <admin-email> <db-name> <db-user> <db-password>
      - Creates a new WordPress site with the given parameters.
      
  sudo $SCRIPT_NAME -rm <site-name> <db-name> <db-user>
      - Removes the site and cleans up configs and database.
      
  sudo $SCRIPT_NAME --help | -h
      - Show this help message.

SITE STORAGE:
  - Sites are created in: $WEB_ROOT/<site-name>/
  - Access URL: http://<site-name>.localhost
  - Apache config: $APACHE_SITES_DIR/<site-name>.conf
  - Logs: $APACHE_LOG_DIR/<site-name>_*.log

REQUIREMENTS:
  - Ubuntu/Debian Linux
  - Apache2 with mod_rewrite enabled
  - MySQL/MariaDB server
  - WP-CLI
  - Root/sudo privileges

EXAMPLES:
  # Create new site
  sudo $SCRIPT_NAME mysite admin mypass admin@example.com mydb myuser mydbpass
  
  # Remove existing site
  sudo $SCRIPT_NAME -rm mysite mydb myuser

SECURITY NOTES:
  - This script is intended for local development only
  - Database passwords are handled securely in memory

VALIDATION RULES:
  - Site names: 2-63 characters, alphanumeric, hyphens, and underscores
    * Must start with alphanumeric character
    * Reserved names: localhost, www, admin, root, mysql, apache, api
  - Database names: 1-64 characters, alphanumeric and underscores only
  - Usernames: 1-32 characters, alphanumeric and underscores only
  - Passwords: minimum 4 characters
  - Email: basic format validation (must contain @ and domain)

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    local required_commands=("apache2" "mysql" "wp" "a2ensite" "a2dissite" "systemctl")
    
    for cmd in "${required_commands[@]}"; do
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
        print_error "Missing dependencies: ${missing_deps[*]}"
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

# Simplified site name validation
validate_site_name() {
    local site_name="$1"
    
    if [[ -z "$site_name" ]]; then
        print_error "Site name cannot be empty"
        return 1
    fi
    
    if [[ ${#site_name} -lt 2 || ${#site_name} -gt 63 ]]; then
        print_error "Site name must be 2-63 characters long"
        return 1
    fi
    
    # Allow alphanumeric, hyphens, and underscores
    if [[ ! "$site_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        print_error "Site name must start with alphanumeric character and contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    # Check for critical reserved names only
    for reserved in "${RESERVED_NAMES[@]}"; do
        if [[ "$site_name" == "$reserved" ]]; then
            print_error "Site name '$site_name' is reserved and cannot be used"
            return 1
        fi
    done
}

# Simplified database validation
validate_database_name() {
    local db_name="$1"
    
    if [[ -z "$db_name" ]]; then
        print_error "Database name cannot be empty"
        return 1
    fi
    
    if [[ ${#db_name} -gt 64 ]]; then
        print_error "Database name must be 64 characters or less"
        return 1
    fi
    
    # MySQL naming rules
    if [[ ! "$db_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "Database name must contain only letters, numbers, and underscores"
        return 1
    fi
}

# Simplified username validation
validate_username() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        print_error "Username cannot be empty"
        return 1
    fi
    
    if [[ ${#username} -gt 32 ]]; then
        print_error "Username must be 32 characters or less"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "Username must contain only letters, numbers, and underscores"
        return 1
    fi
}

# Much more relaxed password validation
validate_password() {
    local password="$1"
    local type="$2"
    
    if [[ -z "$password" ]]; then
        print_error "$type password cannot be empty"
        return 1
    fi
    
    # Only minimum length requirement for local use
    if [[ ${#password} -lt 4 ]]; then
        print_error "$type password must be at least 4 characters long"
        return 1
    fi
}

# Basic email validation
validate_email() {
    local email="$1"
    
    if [[ -z "$email" ]]; then
        print_error "Email cannot be empty"
        return 1
    fi
    
    # Very basic email format check
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        print_error "Invalid email format (must contain @ and domain)"
        return 1
    fi
}

# Execute MySQL command using sudo authentication
execute_mysql() {
    local query="$1"
    
    if ! mysql -u root -e "$query" 2>/dev/null; then
        print_error "MySQL query failed: $query"
        return 1
    fi
}

# Test MySQL connection
test_mysql_connection() {
    print_info "Testing MySQL connection..."
    
    if ! mysql -u root -e "SELECT 1;" &>/dev/null; then
        print_error "MySQL connection failed. Please ensure MySQL is running and accessible."
        return 1
    fi
    
    print_info "MySQL connection successful"
    return 0
}

# Cleanup function for error handling
cleanup_on_error() {
    if [[ "$CLEANUP_NEEDED" == true ]]; then
        print_warning "Cleaning up partial installation..."
        
        # Remove Apache config
        if [[ -f "$APACHE_SITES_DIR/${SITE_NAME}.conf" ]]; then
            a2dissite "${SITE_NAME}.conf" &>/dev/null || true
            rm -f "$APACHE_SITES_DIR/${SITE_NAME}.conf"
        fi
        
        # Remove site directory
        if [[ -d "$SITE_DIR" ]]; then
            rm -rf "$SITE_DIR"
        fi
        
        # Remove hosts entry
        local hosts_line="127.0.0.1 ${SITE_NAME}.localhost"
        if grep -Fxq "$hosts_line" "$HOSTS_FILE"; then
            local tmpfile
            tmpfile=$(mktemp /tmp/hosts.XXXXXX)
            grep -Fxv "$hosts_line" "$HOSTS_FILE" > "$tmpfile"
            cp "$tmpfile" "$HOSTS_FILE"
            rm "$tmpfile"
        fi
        
        systemctl reload apache2 &>/dev/null || true
    fi
}

# Set up error handling
trap cleanup_on_error ERR EXIT

# Create database and user
setup_database() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"
    
    print_info "Creating database '$db_name'..."
    execute_mysql "CREATE DATABASE IF NOT EXISTS \`$db_name\`;"
    
    print_info "Creating database user '$db_user'..."
    execute_mysql "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';"
    
    print_info "Granting privileges..."
    execute_mysql "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'localhost';"
    
    execute_mysql "FLUSH PRIVILEGES;"
}

# Remove database and user
remove_database() {
    local db_name="$1"
    local db_user="$2"
    
    print_info "Dropping database '$db_name'..."
    execute_mysql "DROP DATABASE IF EXISTS \`$db_name\`;"
    
    print_info "Dropping user '$db_user'..."
    execute_mysql "DROP USER IF EXISTS '$db_user'@'localhost';"
    
    # Flush privileges
    execute_mysql "FLUSH PRIVILEGES;"
}

# Create Apache virtual host
create_apache_config() {
    local site_name="$1"
    local site_dir="$2"
    
    local apache_conf="$APACHE_SITES_DIR/${site_name}.conf"
    
    print_info "Creating Apache virtual host configuration..."
    
    cat <<EOF > "$apache_conf"
<VirtualHost *:80>
    ServerName ${site_name}.localhost
    DocumentRoot ${site_dir}
    
    <Directory ${site_dir}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Logging
    ErrorLog ${APACHE_LOG_DIR}/${site_name}_error.log
    CustomLog ${APACHE_LOG_DIR}/${site_name}_access.log combined
    
</VirtualHost>
EOF
}

# Update hosts file
update_hosts_file() {
    local site_name="$1"
    local action="$2"  # add or remove
    
    local hosts_line="127.0.0.1 ${site_name}.localhost"
    
    if [[ "$action" == "add" ]]; then
        if ! grep -Fxq "$hosts_line" "$HOSTS_FILE"; then
            print_info "Adding entry to hosts file..."
            local tmpfile
            tmpfile=$(mktemp /tmp/hosts.XXXXXX)
            echo "$hosts_line" > "$tmpfile"
            cat "$HOSTS_FILE" >> "$tmpfile"
            cp "$tmpfile" "$HOSTS_FILE"
            rm "$tmpfile"
        fi
    elif [[ "$action" == "remove" ]]; then
        if grep -Fxq "$hosts_line" "$HOSTS_FILE"; then
            print_info "Removing entry from hosts file..."
            local tmpfile
            tmpfile=$(mktemp /tmp/hosts.XXXXXX)
            grep -Fxv "$hosts_line" "$HOSTS_FILE" > "$tmpfile"
            cp "$tmpfile" "$HOSTS_FILE"
            rm "$tmpfile"
        fi
    fi
}

# Create WordPress .htaccess with security enhancements
create_htaccess() {
    local site_dir="$1"
    
    print_info "Creating WordPress .htaccess file..."
    
    cat <<EOF > "$site_dir/.htaccess"
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
    
    chown www-data:www-data "$site_dir/.htaccess"
    chmod 644 "$site_dir/.htaccess"
}

# Check if site already exists
check_site_exists() {
    local site_name="$1"
    local site_dir="$WEB_ROOT/$site_name"
    
    if [[ -d "$site_dir" ]] && [[ -n "$(ls -A "$site_dir")" ]]; then
        print_error "Site directory $site_dir already exists and is not empty"
        return 1
    fi
    
    if [[ -f "$APACHE_SITES_DIR/${site_name}.conf" ]]; then
        print_error "Apache configuration for $site_name already exists"
        return 1
    fi
    
    local hosts_line="127.0.0.1 ${site_name}.localhost"
    if grep -Fxq "$hosts_line" "$HOSTS_FILE"; then
        print_error "Hosts entry for ${site_name}.localhost already exists"
        return 1
    fi
}

# Create new WordPress site
create_site() {
    local site_name="$1"
    local admin_name="$2"
    local admin_password="$3"
    local admin_email="$4"
    local db_name="$5"
    local db_user="$6"
    local db_password="$7"
    
    # Set global variables for cleanup
    SITE_NAME="$site_name"
    SITE_DIR="$WEB_ROOT/$site_name"
    DB_NAME="$db_name"
    DB_USER="$db_user"
    CLEANUP_NEEDED=true
    
    # Validate inputs
    validate_site_name "$site_name"
    validate_username "$admin_name"
    validate_password "$admin_password" "Admin"
    validate_email "$admin_email"
    validate_database_name "$db_name"
    validate_username "$db_user"
    validate_password "$db_password" "Database"
    
    # Check if site already exists
    check_site_exists "$site_name"
    
    # Test MySQL connection
    if ! test_mysql_connection; then
        exit 1
    fi
    
    print_separator
    print_info "Creating WordPress site: $site_name"
    print_info "Site will be created at: $SITE_DIR"
    print_info "Access URL: http://${site_name}.localhost"
    print_separator
    
    # Create site directory
    print_info "Creating site directory..."
    mkdir -p "$SITE_DIR"
    chown -R www-data:www-data "$SITE_DIR"
    
    # Setup database
    setup_database "$db_name" "$db_user" "$db_password"
    
    # Install WordPress
    print_info "Downloading WordPress..."
    wp core download --path="$SITE_DIR" --allow-root
    
    print_info "Creating WordPress configuration..."
    wp config create \
        --dbname="$db_name" \
        --dbuser="$db_user" \
        --dbpass="$db_password" \
        --path="$SITE_DIR" \
        --allow-root \
        --extra-php <<PHP
// Security enhancements
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
PHP
    
    print_info "Installing WordPress..."
    wp core install \
        --url="http://${site_name}.localhost" \
        --title="$site_name" \
        --admin_user="$admin_name" \
        --admin_password="$admin_password" \
        --admin_email="$admin_email" \
        --path="$SITE_DIR" \
        --allow-root
    
    # Update WordPress URLs
    wp option update home "http://${site_name}.localhost" --path="$SITE_DIR" --allow-root
    wp option update siteurl "http://${site_name}.localhost" --path="$SITE_DIR" --allow-root
    
    # Create .htaccess
    create_htaccess "$SITE_DIR"
    
    # Create Apache configuration
    create_apache_config "$site_name" "$SITE_DIR"
    
    # Test Apache configuration
    print_info "Testing Apache configuration..."
    if ! apachectl configtest; then
        print_error "Apache configuration test failed"
        exit 1
    fi
    
    # Enable site
    print_info "Enabling Apache site..."
    a2ensite "${site_name}.conf" 2>/dev/null | grep -v "^To activate the new configuration" | grep -v "^  systemctl reload apache2" || true
    
    # Reload Apache
    print_info "Reloading Apache..."
    systemctl reload apache2
    
    # Update hosts file
    update_hosts_file "$site_name" "add"
    
    # Set final permissions
    print_info "Setting file permissions..."
    chown -R www-data:www-data "$SITE_DIR"
    find "$SITE_DIR" -type d -exec chmod 755 {} \;
    find "$SITE_DIR" -type f -exec chmod 644 {} \;
    chmod 644 "$SITE_DIR/wp-config.php"
    
    # Disable cleanup on success
    CLEANUP_NEEDED=false
    
    print_separator
    print_success "WordPress site '$site_name' created successfully!"
    print_info "Do not forget to update permalinks in the WordPress admin panel"
    echo ""
    echo "Site Details:"
    echo "  Site directory: $SITE_DIR"
    echo "  Access URL: http://${site_name}.localhost"
    echo "  Admin user: $admin_name"
    echo "  Database: $db_name"
    echo "  Database user: $db_user"
    echo ""
    echo "Security Notes:"
    echo "  - .htaccess rules applied"
    echo "  - Proper file permissions set"
    print_separator
}

# Remove WordPress site
remove_site() {
    local site_name="$1"
    local db_name="$2"
    local db_user="$3"
    
    # Validate inputs
    validate_site_name "$site_name"
    validate_database_name "$db_name"
    validate_username "$db_user"
    
    local site_dir="$WEB_ROOT/$site_name"
    local apache_conf="$APACHE_SITES_DIR/${site_name}.conf"
    
    # Safety checks
    if [[ -z "$site_name" ]] || [[ "$site_dir" == "$WEB_ROOT/" ]] || [[ "$site_dir" == "/" ]]; then
        print_error "Refusing to delete $site_dir. Invalid or missing site name."
        exit 1
    fi
    
    # Test MySQL connection
    if ! test_mysql_connection; then
        exit 1
    fi
    
    print_separator
    print_warning "DESTRUCTIVE OPERATION WARNING"
    echo ""
    echo "You are about to permanently delete the WordPress site: $site_name"
    echo ""
    echo "This will remove:"
    echo "  - Site directory: $site_dir"
    echo "  - Apache configuration: $apache_conf"
    echo "  - Database: $db_name"
    echo "  - Database user: $db_user"
    echo "  - Hosts file entry: 127.0.0.1 ${site_name}.localhost"
    echo ""
    echo -e "${RED}THIS CANNOT BE UNDONE!${NC}"
    print_separator
    
    # Double confirmation
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " CONFIRM1
    if [[ "$CONFIRM1" != "yes" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
    
    print_separator
    print_info "Removing WordPress site: $site_name"
    
    # Remove Apache configuration
    if [[ -f "$apache_conf" ]]; then
        print_info "Disabling Apache site..."
        a2dissite "${site_name}.conf" 2>/dev/null | grep -v "^To activate the new configuration" | grep -v "^  systemctl reload apache2" || true
        rm -f "$apache_conf"
    fi
    
    # Remove site directory
    if [[ -d "$site_dir" ]]; then
        print_info "Removing site directory..."
        rm -rf "$site_dir"
    fi
    
    # Remove database and user
    remove_database "$db_name" "$db_user"
    
    # Remove hosts entry
    update_hosts_file "$site_name" "remove"
    
    # Test and reload Apache
    print_info "Testing Apache configuration..."
    if ! apachectl configtest; then
        print_error "Apache configuration test failed"
        exit 1
    fi
    
    print_info "Reloading Apache..."
    systemctl reload apache2
    
    print_separator
    print_success "Site $site_name removed successfully."
    print_separator
}

# Main function
main() {
    # Check for help or no arguments
    if [[ $# -eq 0 ]] || [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Check root privileges
    check_root
    
    # Check dependencies
    check_dependencies
    
    # Handle removal
    if [[ "${1:-}" == "-rm" ]]; then
        if [[ $# -ne 4 ]]; then
            print_error "Usage: $SCRIPT_NAME -rm <site-name> <db-name> <db-user>"
            exit 1
        fi
        remove_site "$2" "$3" "$4"
        exit 0
    fi
    
    # Handle creation
    if [[ $# -ne 7 ]]; then
        echo ""
        echo -e "${YELLOW}For help, run: $SCRIPT_NAME --help${NC}"
        echo ""
        print_error "Usage: $SCRIPT_NAME <site-name> <admin-name> <admin-password> <admin-email> <db-name> <db-user> <db-password>"
        exit 1
    fi
    
    create_site "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

# Disable cleanup trap and run main
trap - ERR EXIT
main "$@"