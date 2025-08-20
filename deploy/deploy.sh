#!/bin/bash

# NS Acct Deployment Script for Testnet
# This script helps deploy the ns_acct module to Sui testnet

set -e

echo "🚀 NS Acct Deployment Script"
echo "================================"

# Check if sui client is installed
if ! command -v sui &> /dev/null; then
    echo "❌ Error: sui client is not installed or not in PATH"
    echo "Please install Sui CLI from: https://docs.sui.io/guides/developer/getting-started/sui-install"
    exit 1
fi

# Check current environment
CURRENT_ENV=$(sui client active-env 2>/dev/null || echo "none")
echo "📍 Current Sui environment: $CURRENT_ENV"

# Switch to testnet if not already
if [ "$CURRENT_ENV" != "testnet" ]; then
    echo "🔄 Switching to testnet environment..."
    sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
    sui client switch --env testnet
fi

# Check active address
ACTIVE_ADDRESS=$(sui client active-address 2>/dev/null || echo "none")
if [ "$ACTIVE_ADDRESS" = "none" ]; then
    echo "❌ Error: No active address found"
    echo "Please create an address with: sui client new-address"
    exit 1
fi

echo "📮 Active address: $ACTIVE_ADDRESS"

# Check gas balance
echo "💰 Checking gas balance..."
sui client gas --json > gas_coins.json 2>/dev/null || {
    echo "❌ Error: Unable to fetch gas coins"
    echo "Please ensure you have SUI tokens on testnet"
    echo "Get testnet SUI from: https://docs.sui.io/guides/developer/getting-started/get-coins"
    exit 1
}

GAS_BALANCE=$(cat gas_coins.json | jq '[.[] | .balance] | add // 0')
echo "💰 Available gas: $GAS_BALANCE MIST"

if [ "$GAS_BALANCE" -lt 1000000000 ]; then
    echo "⚠️  Warning: Low gas balance (less than 1 SUI)"
    echo "Get testnet SUI from: https://docs.sui.io/guides/developer/getting-started/get-coins"
fi

# Build the project
echo "🔨 Building project..."
cd "$(dirname "$0")/.."

# Backup original config and use working config
cp Move.toml Move.toml.backup
# The current Move.toml is already fixed for deployment

# Build
if ! sui move build; then
    echo "❌ Build failed!"
    mv Move.toml.backup Move.toml
    rm -f gas_coins.json
    exit 1
fi

echo "✅ Build successful!"

# Deploy
echo "🚀 Deploying to testnet..."
DEPLOY_OUTPUT=$(sui client publish --gas-budget 50000000 --json)

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    
    # Parse deployment output
    echo "$DEPLOY_OUTPUT" > deployment_result.json
    PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
    
    echo "📦 Package ID: $PACKAGE_ID"
    echo "🔗 Explorer: https://suiexplorer.com/object/$PACKAGE_ID?network=testnet"
    
    # Save deployment info
    cat > deployment_info.json << EOF
{
    "packageId": "$PACKAGE_ID",
    "network": "testnet",
    "deployer": "$ACTIVE_ADDRESS",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "explorerUrl": "https://suiexplorer.com/object/$PACKAGE_ID?network=testnet"
}
EOF
    
    echo "💾 Deployment info saved to deployment_info.json"
    
else
    echo "❌ Deployment failed!"
    mv Move.toml.backup Move.toml
    rm -f gas_coins.json
    exit 1
fi

# Restore original Move.toml
mv Move.toml.backup Move.toml

# Cleanup
rm -f gas_coins.json

echo ""
echo "🎉 Deployment Complete!"
echo "==============================="
echo "📦 Package ID: $PACKAGE_ID"
echo "🌐 Network: testnet"
echo "🔗 Explorer: https://suiexplorer.com/object/$PACKAGE_ID?network=testnet"
echo ""
echo "📋 Next Steps:"
echo "1. Update your frontend with the new package ID"
echo "2. Register a parent domain (e.g., youname.acct.sui) on SuiNS testnet"
echo "3. Call setup_wrapper with your parent domain registration"
echo "4. Test the full flow with real .sui domains"
echo ""
echo "💡 For frontend integration, see the examples in the frontend/ directory"
