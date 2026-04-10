#!/bin/bash
set -e

# Target directory mounted in docker-compose.yml
WP_DIR="/mnt/wordpress"
WP_PATH="$WP_DIR"
WP_RUN_AS="www-data"
SETUP_LOG_PREFIX="[manager-install]"

. /project/scripts/wp-setup-common.sh

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-somewordpress}"

SITE_TITLE="${1:-${WP_SITE_TITLE:-wp test}}"
WP_SITE_TITLE="$SITE_TITLE"

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
sudo mysql --skip-ssl -h "$DB_HOST" -P "$DB_PORT" -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME}; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"

echo "Downloading WordPress Core... <br>"
cd "$WP_DIR"
# www-data needs to own the files
wp_cmd core download

echo "Creating wp-config.php... <br>"
wp_cmd config create --dbname="${DB_NAME}" --dbuser="${DB_USER}" --dbpass="${DB_PASSWORD}" --dbhost="${DB_HOST_RAW}"

echo "Running shared WordPress setup... <br>"
run_standard_setup

echo "<h3>Installation Complete!</h3>"
echo "You can access the site at: <a href='${WP_URL}' target='_blank'>${WP_URL}</a> <br>"
echo "Admin Check: user: ${WP_ADMIN_USER}, pass: ${WP_ADMIN_PASSWORD} <br>"
