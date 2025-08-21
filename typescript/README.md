# NS Account Registry Query Tool

Query your NS Account Registry for **FREE** (no gas costs) using simple TypeScript commands.

## 🚀 Quick Start

### 1. Install Dependencies
```bash
cd typescript
bun install
```

### 2. Query Account Data
```bash
# Query specific domain (new simplified command)
bun run query "n-s.acct.sui"

# List all domains
bun run list

# Alternative: direct script execution
bun query-registry.ts "n-s.acct.sui"
bun query-registry.ts --list
```

## 📋 Example Output

### Query Domain:
```
🔍 Looking up: n-s.acct.sui
📡 Resolving reg.acct.sui...
📋 Registry: 0xb8063a009cbcc2310c82cb2c315e5c0196a3b12409d6b88b25f692505966087f

✅ SUCCESS!
──────────────────────────────────────────────────
🔑 Key:    n-s.acct.sui
📝 Data:   External query test data!
👤 Owner:  0x3db42086e9271787046859d60af7933fa7ea70148df37c9fd693195533eabb57
🎯 Target: 0x3db42086e9271787046859d60af7933fa7ea70148df37c9fd693195533eabb57
🆔 Object: 0x9155083e2abbb4fdd5de4e8e983acbfd990837c5bd5314fef3325ce7b60d6e28
──────────────────────────────────────────────────
```

### List Domains:
```
📋 Listing all domains...

📋 Available domains:
  • n-s.acct.sui
```

## 🔧 Usage in Other Projects

You can also import and use the functions in your own TypeScript/JavaScript projects:

```typescript
import { getAccountData, listDomains } from './query-registry';

// Query account data
const data = await getAccountData("n-s.acct.sui");
console.log(data?.data); // "External query test data!"

// List all domains
const domains = await listDomains();
console.log(domains); // ["n-s.acct.sui"]
```

## ✨ Features

- ✅ **Zero gas cost** - pure read operations
- ✅ **Simple CLI** - streamlined `bun run` commands
- ✅ **Modular** - import functions in other projects
- ✅ **Self-contained** - minimal dependencies
- ✅ **Future-proof** - uses stable `reg.acct.sui` entry point
- ✅ **Latest SDK** - updated to use `@mysten/sui` v1.37.4

## 🔧 Dependencies

- **@mysten/sui**: `^1.37.4` - Official Sui TypeScript SDK
- **bun-types**: `latest` - TypeScript support for Bun

## 🌐 Network

Currently configured for **Sui Testnet**. To use on mainnet, change `getFullnodeUrl('testnet')` to `getFullnodeUrl('mainnet')` in `query-registry.ts`.

## 🆕 Recent Updates

- **Fixed SDK compatibility** - Updated from deprecated `@mysten/sui.js` to current `@mysten/sui`
- **Updated API calls** - Fixed `resolveNameServiceAddress` method to use new parameter format
- **Simplified commands** - Added npm script shortcuts for easier usage
- **Enhanced error handling** - Added proper null checks and error messages
