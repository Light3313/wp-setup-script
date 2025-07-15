# createNewSite - WordPress Site Creator/Remover

A bash script for automated creation and removal of local WordPress development sites with Apache and MySQL integration.

# local use only!!!

## Features

- 🚀 **Automated WordPress installation** using WP-CLI
- 🗄️ **Database setup** with MySQL/MariaDB
- 🌐 **Apache virtual host configuration**
- 🔧 **Local hosts file management**
- 🧹 **Cleanup on errors** to prevent partial installations
- ❌ **Safe removal** with confirmation prompts

## Requirements

### System Requirements
- Ubuntu/Debian Linux
- Root/sudo privileges

### Software Dependencies
- **Apache2** with **mod_rewrite** enabled
- **MySQL** or **MariaDB** server
- **WP-CLI** (WordPress Command Line Interface)

### Installation of Dependencies

```bash
# Update package list
sudo apt update

# Install Apache2 and MySQL
sudo apt install apache2 mysql-server

# Enable mod_rewrite
sudo a2enmod rewrite

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Verify WP-CLI installation
wp --info
```

## Installation

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/createNewSite.git
cd createNewSite
```

2. **Make the script executable:**
```bash
chmod +x createNewSite.sh
```

3. **Copy to system PATH (optional):**
```bash
sudo cp createNewSite.sh /usr/local/bin/createNewSite
```

## Usage

**Important:** Site names must not contain spaces. Use `-` or `_` instead of spaces, e.g. `my-site` or `my_site`. Quotes will not bypass this limitation due to script validation.

### Creating a New Site

```bash
sudo createNewSite <site-name> <admin-name> <admin-password> <admin-email> <db-name> <db-user> <db-password>
```

**Example:**
```bash
sudo createNewSite mysite admin MyStrongPass123! admin@example.com mysite_db mysite_user userpass123
```

### Removing a Site

```bash
sudo createNewSite -rm <site-name> <db-name> <db-user> <root-password>
```

**Example:**
```bash
sudo createNewSite -rm mysite mysite_db mysite_user rootpass123
```

### Getting Help

```bash
sudo createNewSite --help
```

## What the Script Does

### Site Creation Process

1. **Validates input parameters** for security and format
2. **Checks system dependencies** (Apache, MySQL, WP-CLI)
3. **Creates site directory** in `/var/www/html/`
4. **Sets up MySQL database** and user with proper permissions
5. **Downloads and installs WordPress** using WP-CLI
6. **Creates Apache virtual host** configuration
7. **Adds entry to `/etc/hosts`** for local access
8. **Sets up WordPress .htaccess** for pretty permalinks
9. **Tests and reloads Apache** configuration

### Site Removal Process

1. **Validates input parameters**
2. **Confirms removal** with user interaction
3. **Disables Apache site** and removes configuration
4. **Removes site directory** and all files
5. **Drops MySQL database** and user
6. **Removes hosts file entry**
7. **Reloads Apache** configuration

## Security Features

- **Input validation** prevents injection attacks
- **Secure password handling** using temporary MySQL config files
- **Path validation** prevents directory traversal attacks
- **Confirmation prompts** for destructive operations
- **Error cleanup** removes partial installations on failure

## File Structure

After installation, your site will be organized as:

```
/var/www/html/mysite/          # WordPress installation
/etc/apache2/sites-available/mysite.conf  # Apache virtual host
/etc/hosts                     # Contains: 127.0.0.1 mysite.localhost
/var/log/apache2/mysite_*.log  # Apache logs
```

## Validation Rules

### Site Name
- Only letters, numbers, hyphens, and underscores
- Cannot start or end with hyphen
- Maximum 63 characters
- Must be unique

### Database Name
- Only letters, numbers, and underscores
- Maximum 64 characters
- Must be unique

### Username
- Only letters, numbers, and underscores
- Maximum 32 characters
- Must be unique

### Email
- Must be valid email format

## Troubleshooting

### Common Issues

**1. "Command not found" errors**
```bash
# Check if dependencies are installed
which apache2 mysql wp

# Install missing dependencies
sudo apt install apache2 mysql-server
```

**2. "Apache config test failed"**
```bash
# Check Apache configuration
sudo apachectl configtest

# Check Apache error logs
sudo tail -f /var/log/apache2/error.log
```

**3. "MySQL connection failed"**
```bash
# Check MySQL service
sudo systemctl status mysql

# Start MySQL if not running
sudo systemctl start mysql
```

**4. "Permission denied" errors**
```bash
# Ensure you're running with sudo
sudo createNewSite --help

# Check file permissions
ls -la /var/www/html/
```

### Cleanup Failed Installation

If something goes wrong during installation, the script automatically cleans up:
- Removes partial Apache configuration
- Deletes site directory
- Removes hosts file entry
- Reloads Apache configuration

### Manual Cleanup

If you need to manually clean up a site:

```bash
# Remove Apache configuration
sudo a2dissite mysite.conf
sudo rm /etc/apache2/sites-available/mysite.conf

# Remove site directory
sudo rm -rf /var/www/html/mysite

# Remove database (replace with your details)
mysql -u root -p -e "DROP DATABASE IF EXISTS mysite_db;"
mysql -u root -p -e "DROP USER IF EXISTS 'mysite_user'@'localhost';"

# Remove hosts entry
sudo sed -i '/127.0.0.1 mysite.localhost/d' /etc/hosts

# Reload Apache
sudo systemctl reload apache2
```

## Security Notes

⚠️ **Important Security Considerations:**

- This script is designed for **local development only**
- Never use this script on production servers
- Use strong, unique passwords for all accounts
- Keep your system and dependencies updated
- Consider using a dedicated development environment

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

### v1.0.0
- Initial release
- Basic site creation and removal functionality
- Security improvements and input validation
- Error handling and cleanup mechanisms
- Comprehensive documentation

## Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing [Issues](https://github.com/yourusername/createNewSite/issues)
3. Create a new issue with detailed information about your problem

## Acknowledgments

- [WP-CLI](https://wp-cli.org/) - WordPress Command Line Interface
- [WordPress](https://wordpress.org/) - Content Management System
- [Apache HTTP Server](https://httpd.apache.org/) - Web Server
- [MySQL](https://www.mysql.com/) - Database Management System