FROM php:8.2-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    mariadb-client \
    curl \
    sudo \
    unzip \
    less \
    nano \
    git \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libzip-dev

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install gd zip exif mysqli pdo pdo_mysql

# Install Docker CLI (client only) to restart containers
RUN curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh && \
    rm get-docker.sh

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy custom PHP settings
COPY custom-php.ini /usr/local/etc/php/conf.d/custom-php.ini

# Allow www-data to run sudo commands (for restart if needed)
RUN echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
