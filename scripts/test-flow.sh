#!/bin/bash

# NS Acct Testing Flow Script
# This script demonstrates the complete flow of using NS Acct with real SuiNS domains

set -e

echo "🧪 NS Acct Testing Flow"
echo "========================"

# Configuration
PACKAGE_ID="" # Will be filled after deployment
PARENT_DOMAIN="nsacct.sui" # Change this to your registered domain
PARENT_WRAPPER_ID="" # Will be filled after setup_wrapper

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
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

# Check if package is deployed
if [ -z "$PACKAGE_ID" ]; then
    print_error "Package not deployed yet!"
    echo "Please deploy the package first using: ./deploy/deploy.sh"
    exit 1
fi

# Check current environment
CURRENT_ENV=$(sui client active-env)
if [ "$CURRENT_ENV" != "testnet" ]; then
    print_warning "Not on testnet environment. Switching..."
    sui client switch --env testnet
fi

ACTIVE_ADDRESS=$(sui client active-address)
print_step "Active address: $ACTIVE_ADDRESS"

echo ""
print_step "Step 1: Check for parent domain registration"
echo "Looking for $PARENT_DOMAIN in your owned objects..."

# Query for SuiNS registrations
REGISTRATIONS=$(sui client objects --filter StructType --type "0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0::suins_registration::SuinsRegistration" --json 2>/dev/null || echo "[]")

if [ "$REGISTRATIONS" = "[]" ] || [ "$(echo $REGISTRATIONS | jq 'length')" = "0" ]; then
    print_error "No SuiNS registrations found!"
    echo "You need to register '$PARENT_DOMAIN' first:"
    echo "1. Go to https://suins.io"
    echo "2. Register '$PARENT_DOMAIN'"
    echo "3. Come back and run this script again"
    exit 1
fi

echo "Found registrations:"
echo "$REGISTRATIONS" | jq -r '.[] | "- " + .objectId + " (Type: " + .type + ")"'

# For testing, let's assume the first registration is our parent domain
PARENT_REG_ID=$(echo "$REGISTRATIONS" | jq -r '.[0].objectId')
print_success "Using registration: $PARENT_REG_ID"

echo ""
print_step "Step 2: Setup parent wrapper (if not done already)"

if [ -z "$PARENT_WRAPPER_ID" ]; then
    print_step "Creating ParentWrapper..."
    
    SETUP_TX=$(sui client call \
        --package $PACKAGE_ID \
        --module ns_acct \
        --function setup_wrapper \
        --args $PARENT_REG_ID \
        --gas-budget 10000000 \
        --json)
    
    if [ $? -eq 0 ]; then
        PARENT_WRAPPER_ID=$(echo "$SETUP_TX" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("ParentWrapper"))) | .objectId')
        print_success "ParentWrapper created: $PARENT_WRAPPER_ID"
        echo "Save this ID in your config: PARENT_WRAPPER_ID=\"$PARENT_WRAPPER_ID\""
    else
        print_error "Failed to create ParentWrapper"
        exit 1
    fi
else
    print_success "ParentWrapper already exists: $PARENT_WRAPPER_ID"
fi

echo ""
print_step "Step 3: Test user flow with a test domain"

# Check if user has any other .sui domains for testing
USER_DOMAINS=$(echo "$REGISTRATIONS" | jq -r '.[1:] | .[] | .objectId' 2>/dev/null || echo "")

if [ -z "$USER_DOMAINS" ]; then
    print_warning "No additional domains found for user testing"
    echo "For a complete test, you need:"
    echo "1. A parent domain (e.g., nsacct.sui) - ✅ Found"
    echo "2. A user domain (e.g., alice.sui) - ❌ Missing"
    echo ""
    echo "To get a test user domain:"
    echo "1. Go to https://suins.io"
    echo "2. Register another domain (e.g., yourname.sui)"
    echo "3. Come back and run this script again"
    echo ""
    print_step "Simulating user flow with mock data..."
    
    # For demonstration, we'll show what the commands would look like
    echo "# Request capability for user domain:"
    echo "sui client call \\"
    echo "    --package $PACKAGE_ID \\"
    echo "    --module ns_acct \\"
    echo "    --function request_cap \\"
    echo "    --args <USER_DOMAIN_ID> \\"
    echo "    --gas-budget 10000000"
    echo ""
    echo "# Create account with subname:"
    echo "sui client call \\"
    echo "    --package $PACKAGE_ID \\"
    echo "    --module ns_acct \\"
    echo "    --function create_with_subname \\"
    echo "    --args 0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0 <USER_DOMAIN_ID> $PARENT_WRAPPER_ID <CAP_ID> 0x6 \\"
    echo "    --gas-budget 50000000"
    
else
    # Test with real user domain
    USER_DOMAIN_ID=$(echo "$USER_DOMAINS" | head -n 1)
    print_step "Testing with user domain: $USER_DOMAIN_ID"
    
    print_step "3a. Request capability..."
    CAP_TX=$(sui client call \
        --package $PACKAGE_ID \
        --module ns_acct \
        --function request_cap \
        --args $USER_DOMAIN_ID \
        --gas-budget 10000000 \
        --json)
    
    if [ $? -eq 0 ]; then
        CAP_ID=$(echo "$CAP_TX" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("SubnameCap"))) | .objectId')
        print_success "Capability created: $CAP_ID"
        
        print_step "3b. Create account with subname..."
        ACCT_TX=$(sui client call \
            --package $PACKAGE_ID \
            --module ns_acct \
            --function create_with_subname \
            --args 0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0 $USER_DOMAIN_ID $PARENT_WRAPPER_ID $CAP_ID 0x6 \
            --gas-budget 50000000 \
            --json)
        
        if [ $? -eq 0 ]; then
            ACCT_ID=$(echo "$ACCT_TX" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("Acct"))) | .objectId')
            print_success "Account created: $ACCT_ID"
            
            print_step "3c. Test account operations..."
            
            # Update value
            sui client call \
                --package $PACKAGE_ID \
                --module ns_acct \
                --function update_value \
                --args $USER_DOMAIN_ID $ACCT_ID 42 \
                --gas-budget 10000000 \
                --json > /dev/null
            
            print_success "Value updated to 42"
            
            # Add field
            sui client call \
                --package $PACKAGE_ID \
                --module ns_acct \
                --function add_field \
                --args $USER_DOMAIN_ID $ACCT_ID "bio" "Hello from NS Acct!" \
                --gas-budget 10000000 \
                --json > /dev/null
            
            print_success "Added field: bio = 'Hello from NS Acct!'"
            
        else
            print_error "Failed to create account"
        fi
    else
        print_error "Failed to request capability"
    fi
fi

echo ""
print_step "Step 4: Query final state"

# Query all Acct objects
ACCOUNTS=$(sui client objects --filter StructType --type "${PACKAGE_ID}::ns_acct::Acct" --json 2>/dev/null || echo "[]")

if [ "$ACCOUNTS" != "[]" ] && [ "$(echo $ACCOUNTS | jq 'length')" != "0" ]; then
    print_success "Found $(echo $ACCOUNTS | jq 'length') account(s):"
    echo "$ACCOUNTS" | jq -r '.[] | "- " + .objectId'
    
    # Get details of first account
    FIRST_ACCT=$(echo "$ACCOUNTS" | jq -r '.[0].objectId')
    print_step "Account details for $FIRST_ACCT:"
    sui client object $FIRST_ACCT --json | jq '.content.fields // .'
else
    print_warning "No accounts found"
fi

echo ""
print_success "Testing flow complete!"
echo ""
echo "🎉 Next Steps:"
echo "1. Use the frontend to interact with your accounts"
echo "2. Register more domains to test the multi-user flow"
echo "3. Build additional features on top of NS Acct"
echo ""
echo "💡 Key IDs for your frontend:"
echo "Package ID: $PACKAGE_ID"
echo "Parent Wrapper ID: $PARENT_WRAPPER_ID"
