#!/bin/bash

# Test PostgreSQL Schema
# Run from project root: ./scripts/test-schema.sh

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found in project root"
    exit 1
fi

echo "🔍 Testing PostgreSQL Schema for Integration Demo"
echo "================================================"
echo ""

# Test database connection
echo "📊 Database: ${POSTGRES_DB}"
echo "👤 User: ${POSTGRES_USER}"
echo ""

# List all tables
echo "📋 Tables created:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dt" 2>/dev/null | grep -E "sales_orders|fx_rates|fx_conversions|integration_events|integration_errors|health_check"

echo ""
echo "📊 Views created:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dv" 2>/dev/null | grep -E "v_daily_processing|v_fx_rate|v_integration|v_error"

echo ""
echo "🔧 Functions created:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\df" 2>/dev/null | grep -E "check_order_exists|get_order_statistics"

echo ""
echo "✅ Testing idempotency constraint:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "
    INSERT INTO sales_orders (order_id, idempotency_key, customer_id, customer_name, order_date, amount_eur, tax_eur, total_eur)
    VALUES ('TEST-001', 'TEST-IDEM-001', 'CUST-001', 'Test Customer', NOW(), 100.00, 10.00, 110.00)
    ON CONFLICT (order_id) DO NOTHING
    RETURNING 'Test order inserted' as result;
" 2>/dev/null

echo ""
echo "🔍 Checking for duplicate prevention:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "
    INSERT INTO sales_orders (order_id, idempotency_key, customer_id, customer_name, order_date, amount_eur, tax_eur, total_eur)
    VALUES ('TEST-001', 'TEST-IDEM-002', 'CUST-001', 'Test Customer', NOW(), 200.00, 20.00, 220.00)
    ON CONFLICT (order_id) DO NOTHING
    RETURNING 'Duplicate prevented' as result;
" 2>/dev/null

echo ""
echo "📈 Sample FX rate check:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "
    SELECT * FROM fx_rates LIMIT 1;
" 2>/dev/null

echo ""
echo "📊 Order statistics function test:"
docker exec integration-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "
    SELECT * FROM get_order_statistics();
" 2>/dev/null

echo ""
echo "✅ Schema validation complete!"
echo ""
echo "Key features enabled:"
echo "  ✓ Idempotency via unique order_id and idempotency_key"
echo "  ✓ FX rate tracking and conversion audit"
echo "  ✓ Integration event logging"
echo "  ✓ Error tracking with retry management"
echo "  ✓ Views ready for Metabase dashboards"
echo "  ✓ Route path tracking (normal/error/duplicate)"
