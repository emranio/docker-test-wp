FROM wordpress:php8.2-apache

# Install libfaketime
RUN apt-get update && apt-get install -y \
    libfaketime \
    && rm -rf /var/lib/apt/lists/*

# Configure libfaketime with file-based timestamp
# libfaketime reads from /etc/faketimerc automatically
ENV LD_PRELOAD=/usr/lib/aarch64-linux-gnu/faketime/libfaketime.so.1
ENV FAKETIME_NO_CACHE=1
ENV FAKETIME_TIMESTAMP_FILE=/etc/faketimerc

# Create default faketimerc (empty = real time)
RUN echo '' > /etc/faketimerc
