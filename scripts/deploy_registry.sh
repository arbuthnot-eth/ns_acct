#!/bin/bash

# NS Account Registry Deployment Script
# Streamlined version for easy deployment and namespace management

set -e

# ============================================
# Configuration
# ============================================
NETWORK="${1:-mainnet}"  # Allow network as first argument, default to mainnet
ACTION="${2:-deploy}"    # Allow action as second argument: deploy, add-namespace, or status

# Package constants  
PACKAGE_NAME="acct_registry"

# Network-specific configurations
case "$NETWORK" in
    "testnet")
        SUINS_REGISTRY_ID="0xb120c0d55432630fce61f7854795a3463deb6e3b443cc4ae72e1282073ff56e4"
        SUI_RPC_URL="https://fullnode.testnet.sui.io:443"
        ;;
    "mainnet")
        SUINS_REGISTRY_ID="0x6e0ddefc0ad98889c04bab9639e512c21766c5e6366f89e696956d9be6952871"
        SUI_RPC_URL="https://sui-rpc.publicnode.com"
        ;;
    *)
        echo "❌ Error: Unsupported network '$NETWORK'"
        echo "Usage: $0 [testnet|mainnet] [deploy|add-namespace|status]"
        exit 1
        ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================

print_header() {
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if jq is installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        echo "Install with: sudo apt-get install jq (Ubuntu) or brew install jq (Mac)"
        exit 1
    fi
    
    if ! command -v sui &> /dev/null; then
        print_error "sui CLI is required but not installed"
        echo "Install from: https://docs.sui.io/guides/developer/getting-started/sui-install"
        exit 1
    fi
}

# Get the current wallet address
get_wallet_address() {
    sui client active-address 2>/dev/null || {
        print_error "No active Sui wallet found"
        echo "Run 'sui client new-address' to create a wallet"
        exit 1
    }
}

# Check if a SuiNS domain resolves to an address
resolve_suins_domain() {
    local domain="$1"
    local rpc_url="$SUI_RPC_URL"
    
    # Split domain into labels and reverse for SuiNS format
    IFS='.' read -ra LABELS <<< "$domain"
    local labels_array=()
    for label in "${LABELS[@]}"; do
        labels_array+=("\"$label\"")
    done
    
    # Reverse the array and join with commas
    local reversed_labels=""
    for (( i=${#labels_array[@]}-1 ; i>=0 ; i-- )) ; do
        if [ -n "$reversed_labels" ]; then
            reversed_labels="$reversed_labels,${labels_array[i]}"
        else
            reversed_labels="${labels_array[i]}"
        fi
    done
    
    local payload='{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "sui_getDynamicFieldObject",
        "params": [
            "'$SUINS_REGISTRY_ID'",
            {
                "type": "0x71af035413ed499710980ed8adb010bbf2cc5cacf4ab37c7710a4bb87eb58ba5::domain::Domain",
                "value": {
                    "labels": ['"$reversed_labels"']
                }
            }
        ]
    }'
    
    local response=$(curl -s -X POST -H "Content-Type: application/json" --data "$payload" "$rpc_url")
    echo "$response" | jq -r '.result.data.content.fields.target_address // empty'
}

# Get registry info from deployment file
get_deployment_info() {
    local deployment_file="deployment_registry.json"
    if [ ! -f "$deployment_file" ]; then
        return 1
    fi
    
    DEPLOYED_NETWORK=$(jq -r '.network // empty' "$deployment_file")
    PACKAGE_ID=$(jq -r '.package_id // empty' "$deployment_file")
    REGISTRY_ID=$(jq -r '.registry_id // empty' "$deployment_file")
    REGISTRY_OWNER_ADDRESS=$(jq -r '.registry_owner_address // empty' "$deployment_file")
    
    if [ "$DEPLOYED_NETWORK" != "$NETWORK" ]; then
        return 1
    fi
    
    if [ -z "$PACKAGE_ID" ] || [ -z "$REGISTRY_ID" ]; then
        return 1
    fi
    
    return 0
}

# ============================================
# Main Functions
# ============================================

# Deploy the registry package and create registry
deploy_registry() {
    print_header "Deploying NS Account Registry to $NETWORK"
    
    local wallet_address=$(get_wallet_address)
    print_success "Using wallet: $wallet_address"
    
    # Build and publish package
    echo "📦 Building package..."
    sui move build
    
    echo "📤 Publishing package to $NETWORK..."
    local publish_output=$(sui client publish --gas-budget 100000000 --json)
    
    # Extract package ID
    PACKAGE_ID=$(echo "$publish_output" | jq -r '.objectChanges[] | select(.type == "published" and .modules[]? == "ns_acct") | .packageId')
    
    if [ -z "$PACKAGE_ID" ]; then
        print_error "Failed to extract package ID from publish output"
        exit 1
    fi
    
    print_success "Package deployed: $PACKAGE_ID"
    
    # Create registry
    echo "⚙️  Creating Registry object..."
    local create_output=$(sui client call --package "$PACKAGE_ID" --module ns_acct --function create_registry --gas-budget 10000000 --json)
    
    REGISTRY_ID=$(echo "$create_output" | jq -r --arg package_id "$PACKAGE_ID" '.objectChanges[] | select(.type == "created" and (.objectType | contains($package_id + "::ns_acct::Registry"))) | .objectId')
    
    if [ -z "$REGISTRY_ID" ]; then
        print_error "Failed to extract Registry ID"
        exit 1
    fi
    
    print_success "Registry created: $REGISTRY_ID"
    REGISTRY_OWNER_ADDRESS="$wallet_address"
    
    # Save deployment info
    cat > deployment_registry.json << EOF
{
    "network": "$NETWORK",
    "package_id": "$PACKAGE_ID",
    "registry_id": "$REGISTRY_ID",
    "registry_owner_address": "$REGISTRY_OWNER_ADDRESS",
    "deployment_time": "$(date -Iseconds)"
}
EOF
    
    print_success "Deployment info saved to deployment_registry.json"
    
    # Add default namespace
    add_namespace "NS"
    
    print_header "Deployment Complete!"
    show_status
}

# Add a namespace to the registry
add_namespace() {
    local namespace="$1"
    
    if [ -z "$namespace" ]; then
        echo "Usage: add_namespace <namespace_name>"
        return 1
    fi
    
    # Load deployment info if not already loaded
    if [ -z "$PACKAGE_ID" ] || [ -z "$REGISTRY_ID" ]; then
        if ! get_deployment_info; then
            print_error "No deployment found for $NETWORK. Run deploy first."
            exit 1
        fi
    fi
    
    echo "🏗️  Adding '$namespace' namespace..."
    
    if sui client call --package "$PACKAGE_ID" --module ns_acct --function add_namespace \
        --args "$REGISTRY_ID" "$namespace" "$REGISTRY_OWNER_ADDRESS" \
        --gas-budget 10000000 > /dev/null 2>&1; then
        print_success "Added '$namespace' namespace"
    else
        print_warning "Failed to add '$namespace' namespace (may already exist)"
    fi
}

# Show current deployment status
show_status() {
    print_header "Registry Status ($NETWORK)"
    
    if ! get_deployment_info; then
        print_warning "No deployment found for $NETWORK"
        return 1
    fi
    
    echo "📋 Package ID: $PACKAGE_ID"
    echo "📋 Registry ID: $REGISTRY_ID"
    echo "📋 Owner Address: $REGISTRY_OWNER_ADDRESS"
    echo ""
    
    # Check if reg.acct.sui points to this registry
    echo "🔍 Checking reg.acct.sui domain..."
    local resolved_address=$(resolve_suins_domain "reg.acct.sui")
    
    if [ "$resolved_address" = "$REGISTRY_ID" ]; then
        print_success "reg.acct.sui correctly points to this registry"
    elif [ -n "$resolved_address" ]; then
        print_warning "reg.acct.sui points to different address: $resolved_address"
        echo "   Expected: $REGISTRY_ID"
    else
        print_warning "reg.acct.sui is not registered or doesn't point to any address"
    fi
    
    echo ""
    echo "🔗 Next steps:"
    echo "   • Update reg.acct.sui to point to: $REGISTRY_ID"
    echo "   • Test with: cd typescript && bun query-ns.ts <domain.sui>"
    echo "   • Add entries using the registry functions"
}

# ============================================
# Main Script Logic
# ============================================

check_dependencies

case "$ACTION" in
    "deploy")
        deploy_registry
        ;;
    "add-namespace")
        namespace="${3}"
        if [ -z "$namespace" ]; then
            echo "Usage: $0 $NETWORK add-namespace <namespace_name>"
            exit 1
        fi
        add_namespace "$namespace"
        ;;
    "status")
        show_status
        ;;
    *)
        echo "❌ Unknown action: $ACTION"
        echo "Usage: $0 [testnet|mainnet] [deploy|add-namespace|status]"
        echo ""
        echo "Examples:"
        echo "  $0 mainnet deploy              # Deploy to mainnet"
        echo "  $0 testnet deploy              # Deploy to testnet"  
        echo "  $0 mainnet add-namespace custom # Add 'custom' namespace"
        echo "  $0 mainnet status              # Show deployment status"
        exit 1
        ;;
esac
