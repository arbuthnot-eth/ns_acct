# NS Acct API Reference

## Module: `ns_acct::ns_acct`

### Data Structures

#### `ParentWrapper`
```move
public struct ParentWrapper has key {
    id: object::UID,
    reg: SuinsRegistration,
}
```
Shared wrapper for the parent SuiNS registration.

#### `SubnameCap`
```move
public struct SubnameCap has key, store {
    id: object::UID,
    reg_id: object::ID,
}
```
Capability proving ownership of a specific domain registration.

#### `Acct`
```move
public struct Acct has key, store {
    id: object::UID,
    reg_id: object::ID,
    value: u64,
    extra_fields: VecMap<String, String>,
}
```
The main account object containing user data.

### Public Functions

#### Setup Functions

##### `setup_wrapper`
```move
public fun setup_wrapper(
    parent_reg: SuinsRegistration, 
    ctx: &mut tx_context::TxContext
)
```
**Purpose**: One-time setup to create a shared ParentWrapper with your parent domain registration.

**Parameters**:
- `parent_reg`: The SuinsRegistration object for your parent domain
- `ctx`: Transaction context

**Effects**:
- Creates a shared ParentWrapper object
- Should only be called once by the parent domain owner

**Example**:
```bash
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function setup_wrapper \
    --args PARENT_DOMAIN_REG_ID \
    --gas-budget 10000000
```

#### User Flow Functions

##### `request_cap`
```move
public fun request_cap(
    user_reg: &SuinsRegistration, 
    ctx: &mut tx_context::TxContext
)
```
**Purpose**: Request a SubnameCap by proving ownership of a .sui domain.

**Parameters**:
- `user_reg`: Reference to the user's SuinsRegistration object
- `ctx`: Transaction context

**Effects**:
- Creates a SubnameCap owned by the transaction sender
- Links the capability to the specific domain registration

**Example**:
```bash
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function request_cap \
    --args USER_DOMAIN_REG_ID \
    --gas-budget 10000000
```

##### `create_with_subname`
```move
public fun create_with_subname(
    suins: &mut SuiNS,
    user_reg: &SuinsRegistration,
    wrapper: &mut ParentWrapper,
    cap: SubnameCap,
    clock: &Clock,
    ctx: &mut tx_context::TxContext
)
```
**Purpose**: Create a shared Acct and leaf subname under the parent domain.

**Parameters**:
- `suins`: Mutable reference to the SuiNS shared object
- `user_reg`: Reference to the user's domain registration
- `wrapper`: Mutable reference to the ParentWrapper
- `cap`: SubnameCap proving domain ownership (consumed)
- `clock`: Reference to the Clock shared object
- `ctx`: Transaction context

**Effects**:
- Creates a shared Acct object
- Creates a leaf subdomain pointing to the account
- Consumes the SubnameCap

**Validation**:
- Capability must match the user registration
- Domain must have valid structure

**Example**:
```bash
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function create_with_subname \
    --args 0x6 USER_DOMAIN_REG_ID PARENT_WRAPPER_ID CAP_ID 0x6 \
    --gas-budget 50000000
```

#### Account Management Functions

##### `update_value`
```move
public fun update_value(
    user_reg: &SuinsRegistration, 
    acct: &mut Acct, 
    new_value: u64
)
```
**Purpose**: Update the static value field of an account.

**Parameters**:
- `user_reg`: Reference to the user's domain registration
- `acct`: Mutable reference to the Acct object
- `new_value`: New value to set

**Access Control**: Only the domain owner can call this function.

**Example**:
```bash
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function update_value \
    --args USER_DOMAIN_REG_ID ACCT_ID 42 \
    --gas-budget 10000000
```

##### `add_field`
```move
public fun add_field(
    user_reg: &SuinsRegistration, 
    acct: &mut Acct, 
    key: String, 
    val: String
)
```
**Purpose**: Add a dynamic key-value field to an account.

**Parameters**:
- `user_reg`: Reference to the user's domain registration
- `acct`: Mutable reference to the Acct object
- `key`: Field name
- `val`: Field value

**Access Control**: Only the domain owner can call this function.

**Example**:
```bash
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function add_field \
    --args USER_DOMAIN_REG_ID ACCT_ID "bio" "Hello World!" \
    --gas-budget 10000000
```

##### `delete_field`
```move
public fun delete_field(
    user_reg: &SuinsRegistration, 
    acct: &mut Acct, 
    key: String
)
```
**Purpose**: Delete a dynamic field from an account.

**Parameters**:
- `user_reg`: Reference to the user's domain registration
- `acct`: Mutable reference to the Acct object
- `key`: Field name to delete

**Access Control**: Only the domain owner can call this function.

**Behavior**: No-op if the field doesn't exist.

**Example**:
```bash
sui client call \
    --package PACKAGE_ID \
    --module ns_acct \
    --function delete_field \
    --args USER_DOMAIN_REG_ID ACCT_ID "bio" \
    --gas-budget 10000000
```

### Getter Functions

##### `value`
```move
public fun value(acct: &Acct): u64
```
**Purpose**: Get the static value field of an account.

**Returns**: The current value

##### `get_field`
```move
public fun get_field(acct: &Acct, key: String): option::Option<String>
```
**Purpose**: Get a dynamic field value by key.

**Returns**: `Some(value)` if the field exists, `None` otherwise

##### `reg_id`
```move
public fun reg_id(acct: &Acct): object::ID
```
**Purpose**: Get the domain registration ID linked to this account.

**Returns**: The object ID of the linked SuinsRegistration

##### `extra_fields`
```move
public fun extra_fields(acct: &Acct): &VecMap<String, String>
```
**Purpose**: Get a reference to all dynamic fields.

**Returns**: Reference to the VecMap containing all fields

##### `extra_fields_length`
```move
public fun extra_fields_length(acct: &Acct): u64
```
**Purpose**: Get the number of dynamic fields.

**Returns**: Count of dynamic fields

### Error Codes

```move
const EMismatch: u64 = 0;          // Capability doesn't match registration
const EInvalidDomain: u64 = 1;     // Domain structure is invalid
const ESubnameAlreadyExists: u64 = 2; // Subdomain already exists
```

### Frontend Integration Examples

#### TypeScript/JavaScript with @mysten/sui.js

##### Query User Domains
```typescript
import { SuiClient } from '@mysten/sui.js/client';

const client = new SuiClient({ url: 'https://fullnode.testnet.sui.io:443' });

async function getUserDomains(address: string) {
  const objects = await client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: `${SUINS_PACKAGE_ID}::suins_registration::SuinsRegistration`
    },
    options: { showContent: true }
  });
  
  return objects.data;
}
```

##### Query User Accounts
```typescript
async function getUserAccounts(address: string) {
  const objects = await client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: `${PACKAGE_ID}::ns_acct::Acct`
    },
    options: { showContent: true }
  });
  
  return objects.data;
}
```

##### Create Account Transaction
```typescript
import { Transaction } from '@mysten/sui.js/transactions';

function createAccountTransaction(
  packageId: string,
  userDomainId: string,
  parentWrapperId: string,
  capId: string
) {
  const tx = new Transaction();
  
  tx.moveCall({
    target: `${packageId}::ns_acct::create_with_subname`,
    arguments: [
      tx.object('0x6'), // SuiNS object
      tx.object(userDomainId),
      tx.object(parentWrapperId),
      tx.object(capId),
      tx.object('0x6'), // Clock object
    ],
  });
  
  return tx;
}
```

##### Update Account Value
```typescript
function updateValueTransaction(
  packageId: string,
  userDomainId: string,
  accountId: string,
  newValue: number
) {
  const tx = new Transaction();
  
  tx.moveCall({
    target: `${packageId}::ns_acct::update_value`,
    arguments: [
      tx.object(userDomainId),
      tx.object(accountId),
      tx.pure.u64(newValue),
    ],
  });
  
  return tx;
}
```

### Common Usage Patterns

#### Complete User Flow
```typescript
// 1. Request capability
const requestCapTx = new Transaction();
requestCapTx.moveCall({
  target: `${packageId}::ns_acct::request_cap`,
  arguments: [requestCapTx.object(userDomainId)]
});

const capResult = await signAndExecuteTransaction({ transaction: requestCapTx });
const capId = extractCreatedObjectId(capResult, 'SubnameCap');

// 2. Create account
const createAccountTx = createAccountTransaction(packageId, userDomainId, parentWrapperId, capId);
const accountResult = await signAndExecuteTransaction({ transaction: createAccountTx });
const accountId = extractCreatedObjectId(accountResult, 'Acct');

// 3. Update account
const updateTx = updateValueTransaction(packageId, userDomainId, accountId, 42);
await signAndExecuteTransaction({ transaction: updateTx });
```

#### Batch Operations
```typescript
// Add multiple fields in one transaction
const tx = new Transaction();

tx.moveCall({
  target: `${packageId}::ns_acct::add_field`,
  arguments: [tx.object(userDomainId), tx.object(accountId), tx.pure.string('bio'), tx.pure.string('Hello!')],
});

tx.moveCall({
  target: `${packageId}::ns_acct::add_field`,
  arguments: [tx.object(userDomainId), tx.object(accountId), tx.pure.string('twitter'), tx.pure.string('@user')],
});

await signAndExecuteTransaction({ transaction: tx });
```

### Best Practices

1. **Error Handling**: Always check transaction results and handle errors gracefully
2. **Gas Estimation**: Use appropriate gas budgets for different operations
3. **Object Caching**: Cache object IDs to avoid repeated queries
4. **Batch Transactions**: Use PTBs for multiple operations
5. **Access Control**: Verify domain ownership before attempting operations
