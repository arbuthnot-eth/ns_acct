#!/bin/bash

# NS Account Registry Deployment Script
# This script deploys the registry contract and sets up reg.acct.sui

set -e

# Configuration
NETWORK="testnet"
PACKAGE_NAME="acct_registry"
REGISTRY_OWNER_ADDRESS="YOUR_ADDRESS_HERE"

echo "🚀 Deploying NS Account Registry to $NETWORK"

# Step 1: Build the package
echo "📦 Building package..."
sui client build

# Step 2: Publish the package
echo "📤 Publishing package to $NETWORK..."
PUBLISH_OUTPUT=$(sui client publish --gas-budget 100000000)

echo "$PUBLISH_OUTPUT"

# Extract package ID and important object IDs
PACKAGE_ID=$(echo "$PUBLISH_OUTPUT" | grep "PackageID:" | cut -d' ' -f2)
REGISTRY_ID=$(echo "$PUBLISH_OUTPUT" | grep "Registry" -A 5 | grep "ObjectID:" | cut -d' ' -f2)

echo "✅ Package deployed successfully!"
echo "📋 Package ID: $PACKAGE_ID"
echo "📋 Registry ID: $REGISTRY_ID"

# Save deployment info
echo "{
    \"network\": \"$NETWORK\",
    \"package_id\": \"$PACKAGE_ID\",
    \"registry_id\": \"$REGISTRY_ID\",
    \"registry_owner\": \"$REGISTRY_OWNER_ADDRESS\",
    \"deployment_time\": \"$(date)\"
}" > deployment_registry.json

echo "💾 Deployment info saved to deployment_registry.json"

# Step 3: Initialize registry (requires acct.sui ownership)
echo "⚙️  Initializing registry..."
if [ -z "$REGISTRY_OWNER_ADDRESS" ] || [ "$REGISTRY_OWNER_ADDRESS" = "YOUR_ADDRESS_HERE" ]; then
    echo "❌ Please set REGISTRY_OWNER_ADDRESS in the script"
    exit 1
fi

echo "🔐 Please ensure you have the following before continuing:"
echo "   1. The address $REGISTRY_OWNER_ADDRESS owns acct.sui"
echo "   2. You have sufficient SUI for gas fees"
echo "   3. You're ready to create reg.acct.sui subname"

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 4: Create reg.acct.sui subname
echo "🌐 Creating reg.acct.sui subname..."
echo "Please create the subname 'reg' under 'acct.sui' via the SuiNS app or SDK"
echo "Set the target address to: $REGISTRY_ID"

read -p "Have you created reg.acct.sui and set its target? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 5: Add initial namespaces
echo "🏗️  Adding initial namespaces..."

echo "Adding 'ns' namespace..."
sui client call --package $PACKAGE_ID --module ns_acct --function add_namespace \
    --args $REGISTRY_ID "ns" $REGISTRY_OWNER_ADDRESS \
    --gas-budget 10000000

echo "✅ Registry deployment completed!"
echo ""
echo "📋 Summary:"
echo "   • Package ID: $PACKAGE_ID"
echo "   • Registry ID: $REGISTRY_ID"
echo "   • Registry Owner: $REGISTRY_OWNER_ADDRESS"
echo "   • Network: $NETWORK"
echo "   • reg.acct.sui resolves to: $REGISTRY_ID"
echo ""
echo "🔗 Next steps:"
echo "   1. Test the registry by adding entries"
echo "   2. Create frontend interface"
echo "   3. Add more namespaces as needed"
echo ""
echo "📚 Usage examples:"
echo "   • Query: cd typescript && bun query-registry.ts \"alice.sui\""
echo "   • Update: sui client call --package $PACKAGE_ID --module ns_acct --function update_entry --args $REGISTRY_ID <SUINS_ID> \"ns\" \"alice.sui\" \"data\" <TARGET_ADDRESS> <CALLER_ADDRESS>"

