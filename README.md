# WordPress Docker Setup

This project provides a Docker environment for WordPress with PHP 8.2, MySQL 8.0, and WP-CLI. It includes a **Manager Dashboard** for automating installs and restarts.

When the stack starts, it bootstraps WordPress automatically with the configured site/admin details, enables debugging, and installs the requested plugins. The startup bootstrap and the manager's clean-install flow now share the same setup logic, so both paths stay aligned.

## Prerequisites

-   Docker
-   Docker Compose

## Quick Start

1.  **Build and Start:** Since we added a custom manager service, build the images first:
    
    ```bash
    docker-compose up -d --build
    ```
    
2.  **Automatic bootstrap:**
    
    -   Site title: `wp test`
    -   Admin username: `admin`
    -   Admin password: `admin`
    -   Admin email: `admin@wptest.local`
    -   Installed + activated plugins (in order): `woocommerce`
    -   Installed but left inactive (in order): `wp-reset`
    -   Debug flags enabled on boot: `WP_DEBUG`, `WP_DEBUG_LOG`, `WP_DEBUG_DISPLAY`
    -   WooCommerce defaults on boot: store country `US`, currency `USD`, onboarding skipped
3.  **Access Sites:**
    
    -   **WordPress Site:** [http://localhost:8000](http://localhost:8000)
    -   **Manager Dashboard:** [http://localhost:8080](http://localhost:8080/manage.php)
    -   **Container names:** `docker-wp-db`, `docker-wp-wordpress`, `docker-wp-cli`, `docker-wp-manager`

## Manager Dashboard Features

-   **Clean Install WP:**
    -   Wipes the database and files.
    -   Reinstalls a fresh WordPress instance via WP-CLI.
    -   Sets up admin user `admin` / `admin`.
-   **System Date/Time & Reboot:**
    -   Updates the configuration with a new target time.
    -   Restarts all containers (simulating a reboot).
    -   _Note: For actual time shifting inside containers, additional `libfaketime` configuration is required in the base images._

## Using WP-CLI Manually

Access the CLI container:

```bash
docker-compose exec wp-cli wp --info
```

## Configuration

Credentials and ports are defined in `.env`.

Plugin bootstrap behavior is also configurable in `.env`:

-   `WP_PLUGINS` for plugins that should be installed and activated
-   `WP_INACTIVE_PLUGINS` for plugins that should be installed but kept inactive

WooCommerce bootstrap defaults are also configurable in `.env`:

-   `WC_STORE_COUNTRY`
-   `WC_STORE_CURRENCY`
-   `WC_SKIP_ONBOARDING`

The WordPress debug log will be written to `wordpress_data/wp-content/debug.log` once WordPress emits debug output.
