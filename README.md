# WordPress Docker Setup

This project provides a Docker environment for WordPress with PHP 8.2, MySQL 8.0, and WP-CLI.
It includes a **Manager Dashboard** for automating installs and restarts.

## Prerequisites

- Docker
- Docker Compose

## Quick Start
1.  **Build and Start:**
    Since we added a custom manager service, build the images first:
    ```bash
    docker-compose up -d --build
    ```

2.  **Access Sites:**
    - **WordPress Site:** [http://localhost:8000](http://localhost:8000)
    - **Manager Dashboard:** [http://localhost:8080/manage.php](http://localhost:8080/manage.php)

## Manager Dashboard Features
- **Clean Install WP:**
    - Wipes the database and files.
    - Reinstalls a fresh WordPress instance via WP-CLI.
    - Sets up admin user `admin` / `password`.
- **System Date/Time & Reboot:**
    - Updates the configuration with a new target time.
    - Restarts all containers (simulating a reboot).
    - *Note: For actual time shifting inside containers, additional `libfaketime` configuration is required in the base images.*

## Using WP-CLI Manually
Access the CLI container:
```bash
docker-compose exec wp-cli wp --info
```

## Configuration
Credentials and ports are defined in `.env`.
