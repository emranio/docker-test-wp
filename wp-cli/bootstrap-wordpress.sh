#!/bin/sh
set -eu

WP_ALLOW_ROOT=true
SETUP_LOG_PREFIX="[wp-bootstrap]"

. /usr/local/bin/wp-setup-common.sh

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

main() {
  export DB_HOST DB_PORT
  wait_for_wordpress_files
  wait_for_database
  wait_for_wp_cli
  run_standard_setup
  echo "[wp-bootstrap] Bootstrap complete. Keeping wp-cli container ready."
  exec tail -f /dev/null
}

main "$@"
