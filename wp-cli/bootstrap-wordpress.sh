#!/bin/sh
set -eu

WP_PATH="${WP_PATH:-/var/www/html}"
WP_URL="${WP_SITE_URL:-http://localhost:8000}"
WP_SITE_TITLE="${WP_SITE_TITLE:-wp test}"
WP_ADMIN_USER="${WP_ADMIN_USER:-admin}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-admin}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@wptest.local}"
WP_PLUGINS="${WP_PLUGINS:-woocommerce}"
DB_HOST_RAW="${WORDPRESS_DB_HOST:-db:3306}"
DB_HOST="${DB_HOST_RAW%%:*}"
DB_PORT="${DB_HOST_RAW#*:}"

if [ "$DB_PORT" = "$DB_HOST_RAW" ]; then
  DB_PORT=3306
fi

wp_cmd() {
  wp --allow-root --path="$WP_PATH" "$@"
}

wait_for_wordpress_files() {
  echo "[wp-bootstrap] Waiting for WordPress files..."
  until [ -f "$WP_PATH/wp-load.php" ] && [ -f "$WP_PATH/wp-config.php" ]; do
    sleep 2
  done
}

wait_for_database() {
  echo "[wp-bootstrap] Waiting for database connection..."
  until php -r '
    $host = getenv("DB_HOST") ?: "db";
    $port = (int) (getenv("DB_PORT") ?: 3306);
    $name = getenv("WORDPRESS_DB_NAME") ?: "wordpress";
    $user = getenv("WORDPRESS_DB_USER") ?: "wordpress";
    $pass = getenv("WORDPRESS_DB_PASSWORD") ?: "wordpress";
    mysqli_report(MYSQLI_REPORT_OFF);
    $mysqli = @new mysqli($host, $user, $pass, $name, $port);
    if ($mysqli->connect_errno) {
        fwrite(STDERR, $mysqli->connect_error . PHP_EOL);
        exit(1);
    }
    $mysqli->close();
  ' >/dev/null 2>&1; do
    sleep 2
  done
}

wait_for_wp_cli() {
  echo "[wp-bootstrap] Waiting for wp-cli to load WordPress..."
  until wp_cmd core version >/dev/null 2>&1; do
    sleep 2
  done
}

ensure_debug_config() {
  echo "[wp-bootstrap] Enforcing debug configuration..."
  wp_cmd config set WP_DEBUG true --raw --type=constant
  wp_cmd config set WP_DEBUG_LOG true --raw --type=constant
  wp_cmd config set WP_DEBUG_DISPLAY true --raw --type=constant
}

ensure_core_install() {
  if wp_cmd core is-installed --skip-plugins --skip-themes >/dev/null 2>&1; then
    echo "[wp-bootstrap] WordPress is already installed. Updating settings..."
  else
    echo "[wp-bootstrap] Installing WordPress core..."
    wp_cmd core install \
      --url="$WP_URL" \
      --title="$WP_SITE_TITLE" \
      --admin_user="$WP_ADMIN_USER" \
      --admin_password="$WP_ADMIN_PASSWORD" \
      --admin_email="$WP_ADMIN_EMAIL" \
      --skip-email \
      --skip-plugins \
      --skip-themes
  fi
}

ensure_site_settings() {
  echo "[wp-bootstrap] Applying site settings..."
  wp_cmd option update home "$WP_URL" --skip-plugins --skip-themes
  wp_cmd option update siteurl "$WP_URL" --skip-plugins --skip-themes
  wp_cmd option update blogname "$WP_SITE_TITLE" --skip-plugins --skip-themes
  wp_cmd option update admin_email "$WP_ADMIN_EMAIL" --skip-plugins --skip-themes

  if wp_cmd user get "$WP_ADMIN_USER" --field=ID --skip-plugins --skip-themes >/dev/null 2>&1; then
    wp_cmd user update "$WP_ADMIN_USER" \
      --user_pass="$WP_ADMIN_PASSWORD" \
      --user_email="$WP_ADMIN_EMAIL" \
      --display_name="$WP_ADMIN_USER" \
      --skip-plugins \
      --skip-themes
  else
    wp_cmd user create "$WP_ADMIN_USER" "$WP_ADMIN_EMAIL" \
      --user_pass="$WP_ADMIN_PASSWORD" \
      --role=administrator \
      --display_name="$WP_ADMIN_USER" \
      --skip-plugins \
      --skip-themes
  fi
}

ensure_plugins() {
  echo "[wp-bootstrap] Installing and activating plugins: $WP_PLUGINS"
  for plugin in $(echo "$WP_PLUGINS" | tr ',' ' '); do
    [ -n "$plugin" ] || continue

    if wp_cmd plugin is-installed "$plugin" --skip-plugins --skip-themes >/dev/null 2>&1; then
      echo "[wp-bootstrap] Plugin already installed: $plugin"
    else
      wp_cmd plugin install "$plugin"
    fi

    if wp_cmd plugin is-active "$plugin" --skip-plugins --skip-themes >/dev/null 2>&1; then
      echo "[wp-bootstrap] Plugin already active: $plugin"
    else
      wp_cmd plugin activate "$plugin"
    fi
  done
}

main() {
  export DB_HOST DB_PORT
  wait_for_wordpress_files
  wait_for_database
  wait_for_wp_cli
  ensure_debug_config
  ensure_core_install
  ensure_site_settings
  ensure_plugins
  echo "[wp-bootstrap] Bootstrap complete. Keeping wp-cli container ready."
  exec tail -f /dev/null
}

main "$@"
