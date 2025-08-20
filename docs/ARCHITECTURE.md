# NS Acct Architecture

## System Overview

NS Acct is a domain-based account system on Sui that creates permanent, decentralized user accounts linked to SuiNS domains. Users who own `.sui` domains can create exactly one account that lives forever and is accessible via a subdomain under a parent domain.

## Core Concepts

### Domain vs Capability Flow

The system uses a dual-layer approach:

1. **Real Domain Registration**: A parent domain (e.g., `nsacct.sui`) must be registered through SuiNS
2. **Capability-Based Access**: Users with any `.sui` domain can request capabilities to create accounts

### Key Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Parent Domain │    │   User Domain    │    │   User Account  │
│   (nsacct.sui)  │    │   (alice.sui)    │    │ (alice.nsacct.sui)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                        │
         │                       │                        │
         ▼                       ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ ParentWrapper   │    │  SubnameCap      │    │      Acct       │
│ (Shared Object) │    │ (Owned Object)   │    │ (Shared Object) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Data Structures

### ParentWrapper
```move
public struct ParentWrapper has key {
    id: object::UID,
    reg: SuinsRegistration,  // The parent domain registration
}
```
- **Purpose**: Wraps the parent domain registration in a shared object
- **Lifecycle**: Created once during setup, lives forever
- **Access**: Shared, can be read by anyone, modified only by the system

### SubnameCap
```move
public struct SubnameCap has key, store {
    id: object::UID,
    reg_id: object::ID,  // Links to user's domain registration
}
```
- **Purpose**: Proves ownership of a specific domain
- **Lifecycle**: Created on demand, consumed when creating account
- **Access**: Owned by the domain owner, transferable

### Acct
```move
public struct Acct has key, store {
    id: object::UID,
    reg_id: object::ID,        // Links to user's domain
    value: u64,                // Example static field
    extra_fields: VecMap<String, String>,  // Dynamic fields
}
```
- **Purpose**: The actual user account with data
- **Lifecycle**: Created once per domain, lives forever
- **Access**: Shared, readable by anyone, modifiable only by domain owner

## Flow Diagrams

### Initial Setup Flow
```
Admin/Deployer
│
├─ 1. Deploy Package
├─ 2. Register Parent Domain (nsacct.sui)
├─ 3. Call setup_wrapper()
│   └─ Creates ParentWrapper (shared)
└─ 4. System Ready
```

### User Account Creation Flow
```
User (owns alice.sui)
│
├─ 1. Call request_cap()
│   ├─ Input: alice.sui registration
│   └─ Output: SubnameCap (owned by user)
│
├─ 2. Call create_with_subname()
│   ├─ Input: alice.sui reg, ParentWrapper, SubnameCap
│   ├─ Creates: Acct (shared)
│   ├─ Creates: alice.nsacct.sui subdomain → points to Acct
│   └─ Consumes: SubnameCap
│
└─ 3. Account Ready
    └─ Accessible at alice.nsacct.sui
```

### Account Management Flow
```
User (with existing account)
│
├─ update_value()
│   ├─ Auth: Must own the linked domain
│   └─ Action: Update static value field
│
├─ add_field()
│   ├─ Auth: Must own the linked domain
│   └─ Action: Add key-value pair
│
└─ delete_field()
    ├─ Auth: Must own the linked domain
    └─ Action: Remove key-value pair
```

## Security Model

### Access Control
- **Domain-Based**: All account modifications require ownership of the linked domain
- **Verification**: `reg_id` matching ensures only domain owners can modify their accounts
- **Immutable Linking**: Once created, the domain-account link cannot be changed

### Object Permissions
- **ParentWrapper**: Shared, read-only for users
- **SubnameCap**: Owned, transferable (could enable delegation)
- **Acct**: Shared, write access only to domain owner

### Attack Vectors & Mitigations

1. **Subdomain Hijacking**: Prevented by consuming capability and immutable subdomains
2. **Account Impersonation**: Prevented by domain ownership verification
3. **Data Tampering**: Prevented by access control checks
4. **Denial of Service**: Mitigated by gas fees and object ownership model

## Technical Details

### SuiNS Integration
```move
// Extract subdomain label from user domain
let user_domain = suins_registration::domain(user_reg);
let subname_label = *domain::label(&user_domain, num_levels - 1);

// Create leaf subdomain
subdomains::new_leaf(
    suins,
    &wrapper.reg,
    clock,
    subname_label,
    acct_addr,
    ctx
);
```

### Error Handling
- `EMismatch`: Capability doesn't match domain registration
- `EInvalidDomain`: Domain structure is invalid
- `ESubnameAlreadyExists`: Subdomain already exists (shouldn't happen with proper flow)

### Gas Optimization
- **Shared Objects**: Reduce gas by avoiding object creation/deletion
- **Capability Consumption**: Clean up temporary objects
- **Batch Operations**: Frontend can use PTBs for multi-step transactions

## Scalability Considerations

### Performance
- **Shared Objects**: Better than owned objects for high-frequency access
- **Object Sharding**: Each account is independent
- **Query Efficiency**: Objects can be indexed by domain or account type

### Limitations
- **One Account Per Domain**: By design, prevents account spam
- **Parent Domain Dependency**: All accounts depend on parent domain health
- **Storage Growth**: Accounts live forever, storage grows monotonically

## Integration Patterns

### Frontend Integration
```typescript
// Query user domains
const domains = await client.getOwnedObjects({
  filter: { StructType: `${SUINS_PACKAGE}::suins_registration::SuinsRegistration` }
});

// Query user accounts
const accounts = await client.getOwnedObjects({
  filter: { StructType: `${PACKAGE_ID}::ns_acct::Acct` }
});
```

### Other dApp Integration
```move
// Other modules can read account data
public fun get_user_bio(acct: &Acct): Option<String> {
    ns_acct::get_field(acct, string::utf8(b"bio"))
}

// Verify account ownership
public fun verify_account_owner(acct: &Acct, user_reg: &SuinsRegistration): bool {
    ns_acct::reg_id(acct) == object::id(user_reg)
}
```

## Future Enhancements

### Potential Features
1. **Account Delegation**: Allow temporary access via transferable capabilities
2. **Social Features**: Friend connections, messaging
3. **Reputation System**: On-chain reputation scores
4. **Multi-Domain Accounts**: Link multiple domains to one account
5. **Account Recovery**: Backup mechanisms using multi-sig

### Upgrade Strategy
- **Module Upgrades**: Use package upgrades for new functionality
- **Data Migration**: Accounts are permanent, new fields can be added
- **Backward Compatibility**: Maintain getter functions for existing data

## Comparison with Alternatives

### vs Traditional Web2 Accounts
- ✅ **Permanent**: Can't be deleted or suspended
- ✅ **Decentralized**: No central authority
- ✅ **Portable**: Can be used across any Sui dApp
- ❌ **Complexity**: Requires blockchain knowledge

### vs Other On-Chain Identity Systems
- ✅ **Domain-Based**: Human-readable addresses
- ✅ **SuiNS Integration**: Leverages existing infrastructure
- ✅ **Capability Model**: Flexible permissions
- ❌ **Domain Dependency**: Requires owning a domain

### vs Simple Object Ownership
- ✅ **Discoverable**: Via subdomains
- ✅ **Structured**: Consistent data format
- ✅ **Updatable**: Mutable fields
- ❌ **Overhead**: More complex than simple objects
