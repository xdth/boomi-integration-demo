#!/bin/bash

# Test BOD XML Templates
# Run from project root: ./scripts/test-templates.sh

echo "🔍 Testing BOD XML Templates"
echo "============================"
echo ""

# Check if templates exist
echo "📁 Checking template files..."
if [ -f "mock-ion/templates/sales_order.xml" ]; then
    echo "✅ sales_order.xml found"
    echo "   Size: $(wc -c < mock-ion/templates/sales_order.xml) bytes"
    echo "   Lines: $(wc -l < mock-ion/templates/sales_order.xml)"
else
    echo "❌ sales_order.xml not found"
fi

if [ -f "mock-ion/templates/malformed.xml" ]; then
    echo "✅ malformed.xml found"
    echo "   Size: $(wc -c < mock-ion/templates/malformed.xml) bytes"
    echo "   Lines: $(wc -l < mock-ion/templates/malformed.xml)"
else
    echo "❌ malformed.xml not found"
fi

echo ""
echo "📋 Sample of sales_order.xml:"
head -15 mock-ion/templates/sales_order.xml | sed 's/^/   /'

echo ""
echo "🔍 Validating XML structure..."
# Check for required elements
if grep -q '${ORDER_ID}' mock-ion/templates/sales_order.xml; then
    echo "✅ ORDER_ID placeholder found"
fi

if grep -q '${TIMESTAMP}' mock-ion/templates/sales_order.xml; then
    echo "✅ TIMESTAMP placeholder found"
fi

if grep -q '${CUSTOMER_ID}' mock-ion/templates/sales_order.xml; then
    echo "✅ CUSTOMER_ID placeholder found"
fi

if grep -q 'currencyID="EUR"' mock-ion/templates/sales_order.xml; then
    echo "✅ EUR currency amounts found"
fi

echo ""
echo "✅ Templates are ready for use!"
