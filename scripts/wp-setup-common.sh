#!/bin/sh

WP_PATH="${WP_PATH:-/var/www/html}"
WP_SITE_TITLE="${WP_SITE_TITLE:-wp test}"
WP_ADMIN_USER="${WP_ADMIN_USER:-admin}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-admin}"
WP_ADMIN_EMAIL="${WP_ADMIN_EMAIL:-admin@wptest.local}"
WP_ACTIVE_PLUGINS="${WP_ACTIVE_PLUGINS:-${WP_PLUGINS:-woocommerce}}"
WP_INACTIVE_PLUGINS="${WP_INACTIVE_PLUGINS:-wp-reset}"
WC_STORE_COUNTRY="${WC_STORE_COUNTRY:-US}"
WC_STORE_CURRENCY="${WC_STORE_CURRENCY:-USD}"
WC_SKIP_ONBOARDING="${WC_SKIP_ONBOARDING:-true}"
DB_HOST_RAW="${WORDPRESS_DB_HOST:-db:3306}"
DB_HOST="${DB_HOST_RAW%%:*}"
DB_PORT="${DB_HOST_RAW#*:}"
DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
DB_USER="${WORDPRESS_DB_USER:-wordpress}"
DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-wordpress}"
WP_ALLOW_ROOT="${WP_ALLOW_ROOT:-false}"
WP_RUN_AS="${WP_RUN_AS:-}"
SETUP_LOG_PREFIX="${SETUP_LOG_PREFIX:-[wp-setup]}"

if [ "$DB_PORT" = "$DB_HOST_RAW" ]; then
  DB_PORT=3306
fi

if [ -n "${WP_SITE_URL:-}" ]; then
  WP_URL="$WP_SITE_URL"
else
  WP_URL="http://localhost:${WP_PORT:-8000}"
fi

log_step() {
  printf '%s %s\n' "$SETUP_LOG_PREFIX" "$*"
}

is_truthy() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

wp_cmd() {
  if [ -n "$WP_RUN_AS" ]; then
    sudo -u "$WP_RUN_AS" wp --path="$WP_PATH" "$@"
  elif is_truthy "$WP_ALLOW_ROOT"; then
    wp --allow-root --path="$WP_PATH" "$@"
  else
    wp --path="$WP_PATH" "$@"
  fi
}

plugin_list_items() {
  printf '%s' "$1" | tr ',' ' '
}

plugin_in_list() {
  plugin_name="$1"
  plugin_list="$2"

  for configured_plugin in $(plugin_list_items "$plugin_list"); do
    [ -n "$configured_plugin" ] || continue

    if [ "$configured_plugin" = "$plugin_name" ]; then
      return 0
    fi
  done

  return 1
}

ensure_debug_config() {
  log_step "Enforcing debug configuration..."
  wp_cmd config set WP_DEBUG true --raw --type=constant
  wp_cmd config set WP_DEBUG_LOG true --raw --type=constant
  wp_cmd config set WP_DEBUG_DISPLAY true --raw --type=constant
}

ensure_core_install() {
  if wp_cmd core is-installed --skip-plugins --skip-themes >/dev/null 2>&1; then
    log_step "WordPress is already installed. Updating settings..."
  else
    log_step "Installing WordPress core..."
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
  log_step "Applying site settings..."
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

ensure_plugin_state() {
  plugin="$1"
  should_activate="$2"

  [ -n "$plugin" ] || return 0

  if wp_cmd plugin is-installed "$plugin" --skip-plugins --skip-themes >/dev/null 2>&1; then
    log_step "Plugin already installed: $plugin"
  else
    log_step "Installing plugin: $plugin"
    wp_cmd plugin install "$plugin"
  fi

  if is_truthy "$should_activate"; then
    if wp_cmd plugin is-active "$plugin" --skip-plugins --skip-themes >/dev/null 2>&1; then
      log_step "Plugin already active: $plugin"
    else
      log_step "Activating plugin: $plugin"
      wp_cmd plugin activate "$plugin"
    fi
  else
    if wp_cmd plugin is-active "$plugin" --skip-plugins --skip-themes >/dev/null 2>&1; then
      log_step "Deactivating plugin: $plugin"
      wp_cmd plugin deactivate "$plugin"
    else
      log_step "Plugin already inactive: $plugin"
    fi
  fi
}

ensure_plugins() {
  log_step "Ensuring active plugins: ${WP_ACTIVE_PLUGINS:-<none>}"
  for plugin in $(plugin_list_items "$WP_ACTIVE_PLUGINS"); do
    ensure_plugin_state "$plugin" true
  done

  log_step "Ensuring installed-only plugins: ${WP_INACTIVE_PLUGINS:-<none>}"
  for plugin in $(plugin_list_items "$WP_INACTIVE_PLUGINS"); do
    [ -n "$plugin" ] || continue

    if plugin_in_list "$plugin" "$WP_ACTIVE_PLUGINS"; then
      log_step "Plugin is configured as both active and installed-only; installed-only state wins: $plugin"
    fi

    ensure_plugin_state "$plugin" false
  done
}

ensure_woocommerce_setup() {
  if ! wp_cmd plugin is-active woocommerce --skip-plugins --skip-themes >/dev/null 2>&1; then
    return
  fi

  log_step "Applying WooCommerce defaults..."
  wp_cmd option update woocommerce_currency "$WC_STORE_CURRENCY" --skip-plugins --skip-themes
  wp_cmd option update woocommerce_default_country "$WC_STORE_COUNTRY" --skip-plugins --skip-themes

  if is_truthy "$WC_SKIP_ONBOARDING"; then
    log_step "Skipping WooCommerce onboarding experience..."
    wp_cmd option update woocommerce_task_list_complete yes --skip-plugins --skip-themes
    wp_cmd option update woocommerce_task_list_hidden yes --skip-plugins --skip-themes
    wp_cmd option update woocommerce_extended_task_list_complete yes --skip-plugins --skip-themes
    wp_cmd option update woocommerce_extended_task_list_hidden yes --skip-plugins --skip-themes
    wp_cmd option update woocommerce_task_list_hidden_lists '["setup","extended"]' --format=json --skip-plugins --skip-themes
    WP_ADMIN_EMAIL="$WP_ADMIN_EMAIL" wp_cmd eval 'update_option( "woocommerce_onboarding_profile", array( "completed" => true, "skipped" => true, "store_email" => getenv( "WP_ADMIN_EMAIL" ) ?: "" ) );' --skip-plugins --skip-themes
    wp_cmd user meta update "$WP_ADMIN_USER" woocommerce_admin_launch_your_store_tour_hidden yes --skip-plugins --skip-themes
    wp_cmd user meta update "$WP_ADMIN_USER" woocommerce_launch_your_store_tour_hidden yes --skip-plugins --skip-themes
  fi
}

run_standard_setup() {
  ensure_debug_config
  ensure_core_install
  ensure_site_settings
  ensure_plugins
  ensure_woocommerce_setup
}
