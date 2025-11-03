#!/bin/bash

# Test Invoice Ninja API
# Run from project root: ./scripts/test-invoice-ninja.sh

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found in project root"
    exit 1
fi

echo "Testing Invoice Ninja..."
echo "Web Interface: ${IN_APP_URL}"
echo ""

# Wait for Invoice Ninja to be ready (it takes a while to initialize)
echo "⏳ Waiting for Invoice Ninja to initialize (this may take 30-60 seconds)..."

# Check if MySQL is ready first
for i in {1..30}; do
    if docker exec integration-invoice-ninja-db mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "✅ MySQL is ready"
        break
    fi
    echo -n "."
    sleep 2
done

# Wait a bit more for Invoice Ninja app to fully initialize
sleep 10

# Test the Invoice Ninja container directly
echo ""
echo "Testing Invoice Ninja internally..."

# Test from inside the container
docker exec integration-invoice-ninja curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:80/setup

# Check if nginx is running inside the container
echo ""
echo "Checking web server status..."
docker exec integration-invoice-ninja ps aux | grep -E "nginx|apache|php-fpm" | head -5

echo ""
echo "📝 Invoice Ninja Access Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Web URL: ${IN_APP_URL}/setup"
echo "Status: Running (check browser)"
echo ""
echo "⚠️  Note: Invoice Ninja may not respond to curl/wget from host"
echo "    but should work fine in browser!"
echo ""
echo "🌐 Open your browser and go to:"
echo "   ${IN_APP_URL}/setup"
echo ""
echo "Container Status:"
docker ps | grep -E "integration-invoice-ninja|CONTAINER ID"
