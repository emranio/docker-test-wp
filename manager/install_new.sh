#!/bin/bash
set -e

# Target directory mounted in docker-compose.yml
WP_DIR="/mnt/wordpress"
# Map Docker Env Vars to Script Vars
DB_HOST="${WORDPRESS_DB_HOST:-db}"
DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
DB_USER="${WORDPRESS_DB_USER:-wordpress}"
DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-wordpress}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-somewordpress}"

# Handle host:port syntax in DB_HOST for mysql client
DB_HOST_ONLY=$(echo "$DB_HOST" | cut -d: -f1)
DB_PORT_ONLY=$(echo "$DB_HOST" | cut -d: -f2)
if [ "$DB_PORT_ONLY" == "$DB_HOST" ]; then
    DB_PORT_ONLY=3306
fi

# WP URL
# If WP_PORT is set, construct URL.
WP_URL="http://localhost:8000"
if [ -n "$WP_PORT" ]; then
    WP_URL="http://localhost:$WP_PORT"
fi

SITE_TITLE="${1:-Test Site}"

echo "<h3>Starting Clean Install...</h3>"
echo "Site Title: $SITE_TITLE <br>"

if [ ! -d "$WP_DIR" ]; then
    echo "Creating directory $WP_DIR... <br>"
    sudo mkdir -p "$WP_DIR"
    sudo chown www-data:www-data "$WP_DIR"
fi

echo "Removing existing files in $WP_DIR... <br>"
# Be very careful here.
sudo rm -rf "$WP_DIR"/*
sudo rm -rf "$WP_DIR"/.* 2>/dev/null || true

echo "Recreating Database... <br>"
# Using root password if available, otherwise try user (which might fail for DROP/CREATE)
# Docker compose passes MYSQL_ROOT_PASSWORD as DB_ROOT_PASSWORD? No, existing .env has DB_ROOT_PASSWORD
# passed as MYSQL_ROOT_PASSWORD in db service.
# Passed as DB_ROOT_PASSWORD or just environment variable to manager?
# In docker-compose I set: MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
# But in manager service environment:
# WORDPRESS_DB_HOST: ... 
# MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD} << I added this in replace_string!

# connect with --skip-ssl to avoid self-signed cert issues in dev
sudo mysql --skip-ssl -h "$DB_HOST_ONLY" -P "$DB_PORT_ONLY" -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME}; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"

echo "Downloading WordPress Core... <br>"
cd "$WP_DIR"
# www-data needs to own the files
sudo -u www-data wp core download 

echo "Creating wp-config.php... <br>"
sudo -u www-data wp config create --dbname="${DB_NAME}" --dbuser="${DB_USER}" --dbpass="${DB_PASSWORD}" --dbhost="${DB_HOST}"

echo "Installing WordPress... <br>"
sudo -u www-data wp core install --url="${WP_URL}" --title="${SITE_TITLE}" --admin_user=admin --admin_password=admin --admin_email=admin@test.local

echo "<h3>Installation Complete!</h3>"
echo "You can access the site at: <a href='${WP_URL}' target='_blank'>${WP_URL}</a> <br>"
echo "Admin Check: user: admin, pass: admin <br>"
