# NS Acct Deployment Guide

## Overview

This guide walks you through deploying the NS Acct system to Sui testnet, setting up the parent domain, and testing the complete flow.

## Prerequisites

1. **Sui CLI**: Install from [Sui docs](https://docs.sui.io/guides/developer/getting-started/sui-install)
2. **Testnet Tokens**: Get from [Sui testnet faucet](https://docs.sui.io/guides/developer/getting-started/get-coins)
3. **SuiNS Domain**: Register a domain on [SuiNS](https://suins.io) for your parent domain

## Step 1: Deploy the Package

```bash
# Navigate to your project
cd ns_acct

# Run the deployment script
./deploy/deploy.sh
```

The script will:
- Switch to testnet environment
- Check your gas balance
- Build the project with testnet dependencies
- Deploy to testnet
- Save deployment info to `deployment_info.json`

**Important**: Save the Package ID from the deployment output!

## Step 2: Register Your Parent Domain

1. Go to [SuiNS.io](https://suins.io)
2. Connect your wallet (same address used for deployment)
3. Register a domain that will serve as your parent (e.g., `nsacct.sui`, `yourproject.sui`)
4. Confirm the transaction

**Note**: This domain will be the parent for all user accounts. Users will get subdomains like `alice.yourproject.sui`.

## Step 3: Setup the Parent Wrapper

After deployment and domain registration, you need to create the shared ParentWrapper object:

```bash
# Replace PACKAGE_ID with your deployed package ID
# Replace DOMAIN_REG_ID with your parent domain's SuinsRegistration object ID

sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function setup_wrapper \
    --args DOMAIN_REG_ID \
    --gas-budget 10000000
```

**How to find your domain registration ID**:
```bash
# Query your SuiNS registrations
sui client objects --filter StructType --type "0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0::suins_registration::SuinsRegistration"
```

Save the ParentWrapper object ID from the transaction output!

## Step 4: Update Frontend Configuration

Update `frontend/src/config/constants.ts` with your deployment info:

```typescript
export const PACKAGE_ID = 'YOUR_PACKAGE_ID_HERE';
export const PARENT_WRAPPER_ID = 'YOUR_PARENT_WRAPPER_ID_HERE';
export const PARENT_DOMAIN = 'yourproject.sui'; // Your registered domain
```

## Step 5: Test the System

Run the automated testing script:

```bash
# Make sure to update PACKAGE_ID and PARENT_WRAPPER_ID in the script first
./scripts/test-flow.sh
```

Or test manually:

### 5.1 Request Capability
```bash
# User must own a .sui domain
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function request_cap \
    --args USER_DOMAIN_REG_ID \
    --gas-budget 10000000
```

### 5.2 Create Account
```bash
# Use the capability ID from the previous transaction
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function create_with_subname \
    --args 0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0 USER_DOMAIN_REG_ID PARENT_WRAPPER_ID CAP_ID 0x6 \
    --gas-budget 50000000
```

### 5.3 Test Account Operations
```bash
# Update value
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function update_value \
    --args USER_DOMAIN_REG_ID ACCT_ID 42 \
    --gas-budget 10000000

# Add field
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function add_field \
    --args USER_DOMAIN_REG_ID ACCT_ID "bio" "Hello World!" \
    --gas-budget 10000000
```

## Step 6: Deploy Frontend

```bash
cd frontend

# Install dependencies
npm install

# Update configuration (see Step 4)
# Start development server
npm run dev

# Or build for production
npm run build
```

## Troubleshooting

### Common Issues

1. **"Build failed"**
   - Ensure you have the correct Sui framework version
   - Check your Move.toml dependencies

2. **"No SuiNS registrations found"**
   - Make sure you registered a domain on SuiNS
   - Verify you're using the same wallet address

3. **"Transaction failed"**
   - Check gas balance (need at least 0.1 SUI)
   - Ensure object IDs are correct
   - Verify you're on testnet

4. **"Frontend not connecting"**
   - Update Package ID and Parent Wrapper ID in constants.ts
   - Make sure wallet is connected to testnet

### Useful Commands

```bash
# Check active environment
sui client active-env

# Switch to testnet
sui client switch --env testnet

# Check gas balance
sui client gas

# Query objects by type
sui client objects --filter StructType --type "PACKAGE_ID::ns_acct::Acct"

# Get object details
sui client object OBJECT_ID
```

## Security Considerations

1. **Testnet Only**: This deployment is for testnet. Mainnet deployment requires additional security reviews.

2. **Access Control**: Only domain owners can modify their accounts - this is enforced by the `reg_id` matching.

3. **Immutable Subdomains**: Once created, subdomains cannot be repointed (by design).

4. **Parent Domain**: Protect the private key of the parent domain owner.

## Next Steps

1. **Custom Features**: Add more fields and functionality to the Acct struct
2. **Frontend Polish**: Improve UI/UX and add more features
3. **Integration**: Connect with other Sui dApps
4. **Mainnet**: When ready, deploy to mainnet with proper security review

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the test logs for error details
3. Ensure all prerequisites are met
4. Verify all object IDs are correct
