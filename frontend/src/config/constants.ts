// NS Acct Configuration Constants

export const NETWORK = 'testnet' as const;

// Updated with deployed package information
export const PACKAGE_ID = '0x03ea89e90deeed29b2d88f510d9517d00a7c30248a2d3744e8e2bd0f3a15c51c'; // Deployed package ID
export const PARENT_WRAPPER_ID = '0x0'; // Not needed for simplified version

// SuiNS Contract Addresses (Testnet)
export const SUINS_PACKAGE_ID = '0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0';
export const SUINS_SUBDOMAINS_PACKAGE_ID = '0xe177697e191327901637f8d2c5ffbbde8b1aaac27ec1024c4b62d1ebd1cd7430';

// Network Configuration
export const RPC_URL = 'https://fullnode.testnet.sui.io:443';
export const EXPLORER_URL = 'https://suiexplorer.com';

// Transaction Settings
export const GAS_BUDGET = 10_000_000; // 0.01 SUI in MIST

// Parent Domain Configuration
export const PARENT_DOMAIN = 'nsacct.sui'; // Change this to your registered domain

// Function Names
export const FUNCTIONS = {
  SETUP_WRAPPER: 'setup_wrapper',
  REQUEST_CAP: 'request_cap',
  CREATE_WITH_SUBNAME: 'create_with_subname',
  UPDATE_VALUE: 'update_value',
  ADD_FIELD: 'add_field',
  DELETE_FIELD: 'delete_field',
} as const;

// Error Messages
export const ERROR_MESSAGES = {
  NO_WALLET: 'Please connect your wallet first',
  NO_DOMAIN: 'You need to own a .sui domain to create an account',
  TRANSACTION_FAILED: 'Transaction failed. Please try again.',
  DOMAIN_NOT_FOUND: 'Domain not found or not owned by you',
  ACCOUNT_EXISTS: 'Account already exists for this domain',
} as const;
