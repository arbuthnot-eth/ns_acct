# NS Account Registry

A domain-verified account system on Sui that integrates with SuiNS for secure, decentralized identity management.

## 🏗️ Architecture

- **Registry**: Top-level container for multiple namespaces
- **Namespace**: Individual namespace containers (e.g., "ns")
- **AcctObject**: Account data objects linked to .sui domains
- **SuiNS Integration**: Cryptographic domain ownership verification

## 🎯 Key Features

- ✅ **Domain Verification**: Only .sui domain owners can create/update entries
- ✅ **Free Queries**: Read account data without gas costs
- ✅ **Stable Discovery**: Access via `reg.acct.sui` domain
- ✅ **Hierarchical Namespaces**: Organized data storage
- ✅ **Production Ready**: Deployed and operational on testnet

## 🚀 Current Deployment (Testnet)

- **Package**: `0xfc0013e0ae7d778cf5702e0e9772a1d4f8a8b99b39395d801b0351b06a4f9918`
- **Registry**: `0xb8063a009cbcc2310c82cb2c315e5c0196a3b12409d6b88b25f692505966087f`
- **Discovery**: `reg.acct.sui` → Registry Object
- **Example Entry**: `n-s.acct.sui` in "ns" namespace

## 📁 Project Structure

```
├── sources/           # Move smart contracts
│   └── registry.move  # Main registry contract
├── tests/            # Test files
├── typescript/       # Query tools (TypeScript)
│   ├── query-registry.ts
│   ├── package.json
│   └── README.md
└── deploy/           # Deployment scripts
    └── deploy_registry.sh
```

## 🔧 Quick Query (Free)

```bash
cd typescript
bun install
bun query-registry.ts "n-s.acct.sui"
```

## 🔒 Security

- **SuiNS Integration**: Domain ownership verified via target address or NFT
- **Access Control**: Only domain owners can modify their accounts
- **No Admin Backdoors**: Production-ready security model

## 📚 Documentation

- **TypeScript Tools**: See `typescript/README.md`
- **Smart Contracts**: See `sources/registry.move`
- **Tests**: See `tests/registry_tests.move`

---

**Live on Sui Testnet** | **Discoverable via `reg.acct.sui`** | **Zero Gas Queries**
