#!/bin/bash

# Test PostgreSQL Connection
# Run from project root: ./scripts/test-postgres.sh

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found in project root"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "Testing PostgreSQL connection..."
echo "Using database: ${POSTGRES_DB} with user: ${POSTGRES_USER}"
echo ""

# Wait for PostgreSQL to be ready
sleep 3

# Test connection using docker exec with env variables
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT 'PostgreSQL is running!' as status;"

# Check if health_check table was created
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT * FROM health_check;"

echo ""
echo "If you see 'PostgreSQL is running!' and the health_check table, the setup is successful!"
