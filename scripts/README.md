# NS Account Registry Deployment Guide

This directory contains deployment scripts for the NS Account Registry system.

## Scripts

### `deploy_registry_clean.sh` (Recommended)
Streamlined deployment script with improved error handling and user experience.

#### Usage
```bash
# Deploy to mainnet (default)
./scripts/deploy_registry_clean.sh mainnet deploy

# Deploy to testnet  
./scripts/deploy_registry_clean.sh testnet deploy

# Check deployment status
./scripts/deploy_registry_clean.sh mainnet status

# Add a new namespace
./scripts/deploy_registry_clean.sh mainnet add-namespace "MyNamespace"
```

#### Features
- ✅ Automatic dependency checking (jq, sui CLI)
- ✅ Network-specific configuration
- ✅ Clear colored output with status indicators
- ✅ Automatic namespace creation (NS)
- ✅ Deployment status validation
- ✅ Error handling and recovery guidance

### `deploy_registry.sh` (Legacy)
Original deployment script with more verbose output and manual steps.

## Deployment Process

1. **Prerequisites**
   ```bash
   # Install dependencies
   sudo apt-get install jq  # or brew install jq on Mac
   
   # Install Sui CLI
   # Follow: https://docs.sui.io/guides/developer/getting-started/sui-install
   
   # Set up wallet
   sui client new-address
   ```

2. **Deploy Registry**
   ```bash
   ./scripts/deploy_registry_clean.sh mainnet deploy
   ```

3. **Set up Domain (Manual)**
   - Register `acct.sui` at [SuiNS](https://suins.io)
   - Create `reg.acct.sui` subdomain
   - Point `reg.acct.sui` target to your registry ID

4. **Verify Deployment**
   ```bash
   ./scripts/deploy_registry_clean.sh mainnet status
   cd typescript && bun query-ns.ts <test-domain.sui>
   ```

## Network Configuration

### Mainnet
- **SuiNS Registry**: `0x6e0ddefc0ad98889c04bab9639e512c21766c5e6366f89e696956d9be6952871`
- **RPC Endpoint**: `https://sui-rpc.publicnode.com`

### Testnet  
- **SuiNS Registry**: `0xb120c0d55432630fce61f7854795a3463deb6e3b443cc4ae72e1282073ff56e4`
- **RPC Endpoint**: `https://fullnode.testnet.sui.io:443`

## Common Issues

### "jq not found"
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

### "sui command not found"
Install the Sui CLI from the official documentation.

### "Failed to add namespace"
- Ensure you're using the correct wallet (registry owner)
- Check that the namespace doesn't already exist
- Verify gas budget is sufficient

### "Domain resolution failed"
- Confirm the SuiNS domain is properly registered
- Check that the target address points to the correct registry ID
- Wait a few minutes for blockchain propagation

## Files Generated

- `deployment_registry.json` - Contains deployment metadata
- Individual transaction logs in terminal output

## Example Output

```bash
$ ./scripts/deploy_registry_clean.sh mainnet status

===========================================
Registry Status (mainnet)
===========================================

📋 Package ID: 0x7a23dd805a4df9039f2b7774cfee2c664708f872a5f6836a844d4e17a0d705af
📋 Registry ID: 0x312a80281457d84a1327b7ed85e70a8ac4f89026f727860066af48fc48d0020c
📋 Owner Address: 0x3db42086e9271787046859d60af7933fa7ea70148df37c9fd693195533eabb57

🔍 Checking reg.acct.sui domain...
✅ reg.acct.sui correctly points to this registry

🔗 Next steps:
   • Test with: cd typescript && bun query-ns.ts <domain.sui>
   • Add entries using the registry functions
```
