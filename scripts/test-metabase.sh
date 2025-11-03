#!/bin/bash

# Test Metabase BI Platform
# Run from project root: ./scripts/test-metabase.sh

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found in project root"
    exit 1
fi

echo "Testing Metabase Business Intelligence..."
echo "Web Interface: http://localhost:3000"
echo ""

# Wait for Metabase to be ready (it takes time to initialize)
echo "⏳ Waiting for Metabase to initialize (this may take 30-60 seconds)..."

# Check if PostgreSQL has the metabase database
echo "Checking PostgreSQL for Metabase database..."
docker exec integration-postgres psql -U ${POSTGRES_USER} -c "\l" | grep -q ${METABASE_DB_NAME} && echo "✅ Metabase database exists" || echo "📝 Metabase will create database on first run"

# Test Metabase API health endpoint
for i in {1..40}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")
    if [ "$response" == "200" ]; then
        echo "✅ Metabase is healthy and responding!"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo ""
echo "📊 Metabase Setup Instructions:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Open browser: http://localhost:3000"
echo "2. Complete initial setup:"
echo "   - Choose language"
echo "   - Create admin account"
echo "   - Skip adding data source (we'll add PostgreSQL later)"
echo ""
echo "3. After setup, add PostgreSQL data source:"
echo "   - Click 'Admin' → 'Databases' → 'Add Database'"
echo "   - Type: PostgreSQL"
echo "   - Host: postgres"
echo "   - Port: 5432"
echo "   - Database: ${POSTGRES_DB}"
echo "   - Username: ${POSTGRES_USER}"
echo "   - Password: [from .env file]"
echo ""
echo "💡 Metabase will be used to visualize:"
echo "   - FX conversion metrics"
echo "   - Invoice creation statistics"
echo "   - Integration performance metrics"
echo "   - Error rates and patterns"
echo ""
echo "Container Status:"
docker ps | grep -E "metabase|CONTAINER ID"
