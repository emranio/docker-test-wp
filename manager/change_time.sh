#!/bin/bash
set -e

NEW_TIME="$1"

echo "Current perceived time: $(date '+%d %b, %Y %I:%M:%S%p')"
echo ""
echo "Setting fake time to: $NEW_TIME"
echo ""

# Write faketime directly into the running WordPress container's /etc/faketimerc
# libfaketime reads this file automatically - no restart needed!
CONTAINER="docker-test-wp-wordpress-1"

if sudo docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    echo "Writing @${NEW_TIME} to /etc/faketimerc in ${CONTAINER}..."
    echo "@${NEW_TIME}" | sudo docker exec -i "$CONTAINER" tee /etc/faketimerc > /dev/null
    echo "✓ Faketime written to container"
    echo ""
    
    # Restart Apache inside the container so PHP picks up the new time
    echo "Restarting Apache inside WordPress container..."
    sudo docker exec "$CONTAINER" apache2ctl graceful 2>&1 || true
    echo "✓ Apache restarted"
else
    echo "✗ Container ${CONTAINER} not found!"
    exit 1
fi

echo ""

# Verify the time inside the container
echo "Verifying new time inside WordPress container..."
CONTAINER_TIME=$(sudo docker exec "$CONTAINER" date '+%d %b, %Y %I:%M:%S%p' 2>&1)
echo "WordPress now sees time as: ${CONTAINER_TIME}"

echo ""
echo "✓ Done! WordPress is now operating at: $NEW_TIME"
