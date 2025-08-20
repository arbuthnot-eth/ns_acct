# NS Acct - Domain-based Accounts on Sui

A decentralized account system that creates permanent user accounts linked to SuiNS domains. Own a `.sui` domain, get a permanent account accessible via a human-readable subdomain.

## 🌟 Features

- **Domain-Based Identity**: Link accounts to your `.sui` domains
- **Permanent Accounts**: Accounts live forever, can't be deleted
- **Human-Readable Addresses**: Access accounts via subdomains (e.g., `alice.nsacct.sui`)
- **Capability-Based Security**: Proof-of-ownership using blockchain capabilities
- **Dynamic Fields**: Add/remove custom metadata fields
- **SuiNS Integration**: Built on top of SuiNS infrastructure

## 🏗️ Architecture

```
User owns alice.sui → Gets alice.nsacct.sui → Points to Account Object
                           ↳ Permanent, shared, updatable only by alice.sui owner
```

### Core Flow
1. **Admin Setup**: Deploy package, register parent domain (e.g., `nsacct.sui`), create ParentWrapper
2. **User Registration**: Users with `.sui` domains request capabilities and create accounts
3. **Account Management**: Update values, add/remove fields, all gated by domain ownership

## 🚀 Quick Start

### Prerequisites
- [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install)
- Testnet SUI tokens
- A `.sui` domain from [SuiNS](https://suins.io)

### Deploy to Testnet

```bash
# Clone and navigate
git clone <repository>
cd ns_acct

# Deploy
./deploy/deploy.sh

# Test the system
./scripts/test-flow.sh
```

### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

Update `frontend/src/config/constants.ts` with your deployment IDs.

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [Architecture](docs/ARCHITECTURE.md) - System design and technical details
- [API Reference](docs/API_REFERENCE.md) - Complete function reference

## 🔧 Usage Examples

### Create an Account

```bash
# 1. Request capability (proves you own a domain)
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function request_cap \
    --args YOUR_DOMAIN_REG_ID \
    --gas-budget 10000000

# 2. Create account with subdomain
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function create_with_subname \
    --args 0x6 YOUR_DOMAIN_REG_ID PARENT_WRAPPER_ID CAP_ID 0x6 \
    --gas-budget 50000000
```

### Update Account Data

```bash
# Update static value
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function update_value \
    --args YOUR_DOMAIN_REG_ID ACCOUNT_ID 42 \
    --gas-budget 10000000

# Add custom field
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function add_field \
    --args YOUR_DOMAIN_REG_ID ACCOUNT_ID "bio" "Hello World!" \
    --gas-budget 10000000
```

### Frontend Integration

```typescript
import { Transaction } from '@mysten/sui.js/transactions';

// Create account transaction
const tx = new Transaction();
tx.moveCall({
  target: `${packageId}::ns_acct::create_with_subname`,
  arguments: [
    tx.object('0x6'), // SuiNS
    tx.object(userDomainId),
    tx.object(parentWrapperId),
    tx.object(capId),
    tx.object('0x6'), // Clock
  ],
});

await signAndExecuteTransaction({ transaction: tx });
```

## 🔒 Security

- **Access Control**: Only domain owners can modify their accounts
- **Immutable Links**: Domain-account relationships are permanent
- **Shared Objects**: Accounts are readable by everyone, writable only by owners
- **Capability System**: Temporary, transferable proofs of ownership

## 🧪 Testing

### Run Unit Tests
```bash
sui move test
```

### Integration Testing
```bash
# Update IDs in the script first
./scripts/test-flow.sh
```

### Frontend Testing
```bash
cd frontend
npm run build  # Check for build errors
npm run lint   # Check code quality
```

## 🛠️ Development

### Project Structure
```
ns_acct/
├── sources/           # Move smart contracts
├── tests/            # Move unit tests
├── deploy/           # Deployment scripts and configs
├── frontend/         # React frontend
├── scripts/          # Testing and utility scripts
└── docs/            # Documentation
```

### Key Files
- `sources/ns_acct.move` - Main smart contract
- `frontend/src/hooks/useNSAcct.ts` - React integration
- `frontend/src/config/constants.ts` - Configuration
- `deploy/deploy.sh` - Deployment automation

## 🔮 Future Enhancements

- **Account Delegation**: Temporary access via transferable capabilities
- **Social Features**: Friend connections and messaging
- **Multi-Domain Support**: Link multiple domains to one account
- **Recovery Mechanisms**: Backup and recovery systems
- **Integration Toolkit**: Easy integration for other dApps

## 📝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## ⚖️ License

Apache 2.0 License - see LICENSE file for details.

## 🤝 Support

- Documentation: Check the `docs/` directory
- Issues: Use GitHub issues for bug reports
- Discussions: Use GitHub discussions for questions

## 🔗 Links

- [SuiNS](https://suins.io) - Register .sui domains
- [Sui Documentation](https://docs.sui.io) - Learn about Sui development
- [Move Language](https://move-language.github.io/move/) - Smart contract language

---

Built with ❤️ for the Sui ecosystem. Powered by [SuiNS](https://suins.io).