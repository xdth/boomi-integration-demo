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

# Test the API endpoint
echo ""
echo "Testing Invoice Ninja API health..."

# Check if the app is responding
response=$(curl -s -o /dev/null -w "%{http_code}" ${IN_APP_URL}/api/v1/ping 2>/dev/null || echo "000")

if [ "$response" == "404" ] || [ "$response" == "200" ] || [ "$response" == "401" ]; then
    echo "✅ Invoice Ninja is responding (HTTP $response)"
    echo ""
    echo "📝 Invoice Ninja Setup Instructions:"
    echo "1. Open browser: ${IN_APP_URL}"
    echo "2. You'll see the setup wizard"
    echo "3. Complete the initial setup:"
    echo "   - Test PDF generation (can skip)"
    echo "   - Database connection is pre-configured"
    echo "   - Create admin account"
    echo "   - Configure company details"
    echo ""
    echo "🔑 For API testing later:"
    echo "   - Generate API token after setup"
    echo "   - Will be used for invoice creation"
else
    echo "⚠️  Invoice Ninja not ready yet (HTTP $response)"
    echo "It may still be initializing. Wait a minute and try again."
    echo "Check logs: docker logs integration-invoice-ninja"
fi

# Show container status
echo ""
echo "Container Status:"
docker ps | grep -E "integration-invoice-ninja|CONTAINER ID"
