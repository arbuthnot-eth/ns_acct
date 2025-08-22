#!/bin/bash

# NS Account Registry Deployment Script
# This script deploys the registry contract and sets up reg.acct.sui

set -e

# Configuration
NETWORK="testnet"
PACKAGE_NAME="acct_registry"
REGISTRY_OWNER_NAME="reg.acct.sui"

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

# Step 3: Resolve .sui name to address
echo "🔍 Resolving $REGISTRY_OWNER_NAME to address..."
REGISTRY_OWNER_ADDRESS=$(bun -e "import { resolveSuiName } from './typescript/resolve-sui-name.ts'; resolveSuiName('$REGISTRY_OWNER_NAME').then(address => { if (address) console.log(address); else process.exit(1); });")

if [ $? -ne 0 ] || [ -z "$REGISTRY_OWNER_ADDRESS" ]; then
    echo "❌ Failed to resolve $REGISTRY_OWNER_NAME"
    exit 1
fi

if [ -z "$REGISTRY_OWNER_ADDRESS" ]; then
    echo "❌ Could not extract address from resolve output"
    exit 1
fi

echo "✅ Resolved $REGISTRY_OWNER_NAME to: $REGISTRY_OWNER_ADDRESS"

# Save deployment info
echo "{
    \"network\": \"$NETWORK\",
    \"package_id\": \"$PACKAGE_ID\",
    \"registry_id\": \"$REGISTRY_ID\",
    \"registry_owner_name\": \"$REGISTRY_OWNER_NAME\",
    \"registry_owner_address\": \"$REGISTRY_OWNER_ADDRESS\",
    \"deployment_time\": \"$(date)\"
}" > deployment_registry.json

echo "💾 Deployment info saved to deployment_registry.json"

# Step 4: Initialize registry (requires acct.sui ownership)
echo "⚙️  Initializing registry..."
if [ -z "$REGISTRY_OWNER_ADDRESS" ]; then
    echo "❌ Failed to resolve registry owner address"
    exit 1
fi

echo "🔐 Please ensure you have the following before continuing:"
echo "   1. The name $REGISTRY_OWNER_NAME resolves to your address"
echo "   2. You have sufficient SUI for gas fees"
echo "   3. You're ready to create reg.acct.sui subname"

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 4: Check if reg.acct.sui needs to be updated
echo "🌐 Checking reg.acct.sui target..."
CURRENT_REGISTRY_ID=$(bun -e "import { resolveSuiName } from './typescript/resolve-sui-name.ts'; resolveSuiName('reg.acct.sui').then(address => { if (address) console.log(address); else process.exit(1); });")

if [ "$CURRENT_REGISTRY_ID" = "$REGISTRY_ID" ]; then
    echo "✅ reg.acct.sui already points to the newly deployed registry ID: $REGISTRY_ID"
    echo "   No update needed."
else
    echo "⚠️  reg.acct.sui currently points to a different registry ID."
    echo "   Current target: $CURRENT_REGISTRY_ID"
    echo "   New registry ID: $REGISTRY_ID"
    echo ""
    echo "   You will need to update reg.acct.sui to point to the new registry ID."
    echo "   This can be done via the SuiNS app or SDK."
    
    read -p "Press Enter to continue after updating reg.acct.sui, or Ctrl+C to abort: "
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
echo "   • Registry Owner Name: $REGISTRY_OWNER_NAME"
echo "   • Registry Owner Address: $REGISTRY_OWNER_ADDRESS"
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
echo "   • Update with NFT: sui client call --package $PACKAGE_ID --module ns_acct --function update_entry_with_nft --args $REGISTRY_ID <SUINS_ID> <NFT_ID> \"ns\" \"data\""
echo "   • Update fallback: sui client call --package $PACKAGE_ID --module ns_acct --function update_entry --args $REGISTRY_ID <SUINS_ID> \"ns\" \"alice.sui\" \"data\" <CALLER_ADDRESS>"

