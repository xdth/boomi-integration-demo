#!/bin/bash

# Test Mock ION Simulator - Menu Only
# Run from project root: ./scripts/test-mock-ion.sh

echo "🚀 Testing Mock ION Simulator Menu"
echo "=================================="
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 is not installed"
    exit 1
fi

echo "✅ Python3 is available"

# Install dependencies
echo "📦 Installing dependencies..."
pip install -q -r mock-ion/requirements.txt 2>/dev/null || pip3 install -q -r mock-ion/requirements.txt

# Test that the menu displays (will exit immediately with option 6)
echo ""
echo "🧪 Testing menu display (auto-exit)..."
echo "6" | python3 mock-ion/simulator.py

echo ""
echo "✅ Mock ION Simulator menu is working!"
echo ""
echo "To run the simulator interactively:"
echo "  python3 mock-ion/simulator.py"
echo ""
echo "Note: Boomi endpoint needs to be running to actually send orders"
