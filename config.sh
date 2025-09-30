#!/bin/bash

# createNewSite Configuration File
# Version: 1.0.0
# Author: Light
# License: MIT

# Prevent multiple sourcing
if [[ -n "${CONFIG_LOADED:-}" ]]; then
    return 0
fi
readonly CONFIG_LOADED=true

# Script Information
if [[ -z "${CONFIG_SCRIPT_NAME:-}" ]]; then
    readonly CONFIG_SCRIPT_NAME="createNewSite"
    readonly CONFIG_SCRIPT_VERSION="1.0.0"
    readonly CONFIG_SCRIPT_AUTHOR="Light"
    readonly CONFIG_SCRIPT_LICENSE="MIT"
fi

# System Paths
if [[ -z "${APACHE_SITES_DIR:-}" ]]; then
    readonly APACHE_SITES_DIR="/etc/apache2/sites-available"
    readonly APACHE_ENABLED_DIR="/etc/apache2/sites-enabled"
    readonly WEB_ROOT="/var/www/html"
    readonly HOSTS_FILE="/etc/hosts"
    readonly APACHE_LOG_DIR="/var/log/apache2"
fi

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly PURPLE='\033[1;35m'
readonly CYAN='\033[1;36m'
readonly NC='\033[0m' # No Color

# Reserved names that shouldn't be used as site names
readonly RESERVED_NAMES=(
    "localhost" "www" "admin" "root" "mysql" "apache" "api"
    "test" "dev" "staging" "production" "backup" "temp"
)

# Validation Rules
readonly MIN_SITE_NAME_LENGTH=2
readonly MAX_SITE_NAME_LENGTH=63
readonly MAX_DB_NAME_LENGTH=64
readonly MAX_USERNAME_LENGTH=32
readonly MIN_PASSWORD_LENGTH=4

# Required Commands
readonly REQUIRED_COMMANDS=(
    "apache2" "mysql" "wp" "a2ensite" "a2dissite" "systemctl"
)

# WordPress Default Settings
readonly WP_DEBUG=false
readonly WP_DEBUG_LOG=false
readonly WP_DEBUG_DISPLAY=false

# File Permissions
readonly DEFAULT_DIR_PERMISSIONS=755
readonly DEFAULT_FILE_PERMISSIONS=644
readonly HTACCESS_PERMISSIONS=644
readonly WP_CONFIG_PERMISSIONS=644

# Apache Configuration Template
readonly APACHE_CONFIG_TEMPLATE='<VirtualHost *:80>
    ServerName {SITE_NAME}.localhost
    DocumentRoot {SITE_DIR}
    
    <Directory {SITE_DIR}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Logging
    ErrorLog {APACHE_LOG_DIR}/{SITE_NAME}_error.log
    CustomLog {APACHE_LOG_DIR}/{SITE_NAME}_access.log combined
    
</VirtualHost>'

# WordPress .htaccess Template
readonly HTACCESS_TEMPLATE='# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress'

# WordPress Extra PHP Configuration
readonly WP_EXTRA_PHP='// Security enhancements
define("WP_DEBUG", false);
define("WP_DEBUG_LOG", false);
define("WP_DEBUG_DISPLAY", false);'

# Error Messages
readonly ERROR_ROOT_REQUIRED="This script must be run as root (use sudo)"
readonly ERROR_MISSING_DEPS="Missing dependencies"
readonly ERROR_MYSQL_CONNECTION="MySQL connection failed"
readonly ERROR_APACHE_CONFIG="Apache configuration test failed"
readonly ERROR_SITE_EXISTS="Site already exists"
readonly ERROR_INVALID_SITE_NAME="Invalid site name"
readonly ERROR_INVALID_DB_NAME="Invalid database name"
readonly ERROR_INVALID_USERNAME="Invalid username"
readonly ERROR_INVALID_PASSWORD="Invalid password"
readonly ERROR_INVALID_EMAIL="Invalid email format"

# Success Messages
readonly SUCCESS_SITE_CREATED="WordPress site created successfully"
readonly SUCCESS_SITE_REMOVED="Site removed successfully"
readonly SUCCESS_MYSQL_CONNECTION="MySQL connection successful"

# Info Messages
readonly INFO_CREATING_SITE="Creating WordPress site"
readonly INFO_REMOVING_SITE="Removing WordPress site"
readonly INFO_TESTING_MYSQL="Testing MySQL connection"
readonly INFO_CREATING_DB="Creating database"
readonly INFO_CREATING_USER="Creating database user"
readonly INFO_GRANTING_PRIVILEGES="Granting privileges"
readonly INFO_DOWNLOADING_WP="Downloading WordPress"
readonly INFO_CREATING_CONFIG="Creating WordPress configuration"
readonly INFO_INSTALLING_WP="Installing WordPress"
readonly INFO_CREATING_HTACCESS="Creating WordPress .htaccess file"
readonly INFO_CREATING_APACHE_CONFIG="Creating Apache virtual host configuration"
readonly INFO_TESTING_APACHE="Testing Apache configuration"
readonly INFO_ENABLING_SITE="Enabling Apache site"
readonly INFO_RELOADING_APACHE="Reloading Apache"
readonly INFO_SETTING_PERMISSIONS="Setting file permissions"
readonly INFO_UPDATING_HOSTS="Updating hosts file"

# Warning Messages
readonly WARNING_CLEANUP="Cleaning up partial installation"
readonly WARNING_DESTRUCTIVE="DESTRUCTIVE OPERATION WARNING"
readonly WARNING_CANNOT_UNDO="THIS CANNOT BE UNDONE"

# Help Text
readonly HELP_TEXT="$CONFIG_SCRIPT_NAME - Automated WordPress Site Creator/Remover v$CONFIG_SCRIPT_VERSION

DESCRIPTION:
  This script creates or removes a local WordPress site with Apache and MySQL integration.
  It sets up the site directory, database, Apache virtual host, hosts entry, and WordPress installation.

USAGE:
  sudo $CONFIG_SCRIPT_NAME <site-name> <admin-name> <admin-password> <admin-email> <db-name> <db-user> <db-password>
      - Creates a new WordPress site with the given parameters.
      
  sudo $CONFIG_SCRIPT_NAME -rm <site-name> <db-name> <db-user>
      - Removes the site and cleans up configs and database.
      
  sudo $CONFIG_SCRIPT_NAME --help | -h
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
  sudo $CONFIG_SCRIPT_NAME mysite admin mypass admin@example.com mydb myuser mydbpass
  
  # Remove existing site
  sudo $CONFIG_SCRIPT_NAME -rm mysite mydb myuser

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
  - Email: basic format validation (must contain @ and domain)"
