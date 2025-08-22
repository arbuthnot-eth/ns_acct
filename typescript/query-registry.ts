import { SuiClient } from '@mysten/sui/client';
import { SuinsClient } from '@mysten/suins';

// Constants
const NETWORK = 'testnet';
const NAMESPACE = 'ns';

interface AccountDataResult {
  key: string;
  data: any | null;
  target: string | null;
  owner: string | null;
  ownerDisplay: string | null;
  targetDisplay: string | null;
}

async function getRPC_URL(network: string): Promise<string> {
  switch (network) {
    case 'testnet':
      return 'https://sui-testnet-rpc.publicnode.com';
    case 'mainnet':
      return 'https://sui-mainnet-rpc.publicnode.com';
    default:
      throw new Error(`Unsupported network: ${network}`);
  }
}

// Utility function to shorten addresses consistently
function shortenAddress(address: string): string {
  if (!address || address.length < 12) return address;
  return `${address.slice(0, 6)}...${address.slice(-5)}`;
}

// Helper function for reverse resolution using official SuiNS API
async function resolveReverseName(client: SuiClient, address: string): Promise<string | null> {
  try {
    // Use the official suix_resolveNameServiceNames RPC method
    const response = await client.call('suix_resolveNameServiceNames', [address, null, 1]) as any;
    
    if (response && response.data && response.data.length > 0) {
      return response.data[0]; // Return the primary name (first one)
    }
    
    return null;
  } catch (error) {
    console.debug(`Error in reverse resolution for ${address}:`, error);
    return null;
  }
}

// Note: Manual subname resolution removed - SuinsClient handles this automatically

async function getAccountData(domain: string, defaultToOwner: boolean = false) {
  const result: AccountDataResult = {
    key: domain,
    data: null,
    target: null,
    owner: null,
    ownerDisplay: null,
    targetDisplay: null,
  };

  const client = new SuiClient({ url: await getRPC_URL(NETWORK) });
  const suinsClient = new SuinsClient({ client, network: NETWORK });

  try {
    // Step 1: Resolve SuiNS name using getNameRecord
    let nameRecord = await suinsClient.getNameRecord(domain);
    let suinsObjectId = nameRecord?.nftId || null;
    let targetAddress = nameRecord?.targetAddress || null;

    if (!suinsObjectId) {
      console.log(`❌ Domain '${domain}' is not registered in SuiNS ${NETWORK} registry`);
      return result;
    }
    console.log(`🔍 ${domain} resolved: ${targetAddress ? shortenAddress(targetAddress) : 'null'}`);

    // Step 2: Fetch SuiNS object details (for owner)
    let suinsObject = await client.getObject({
      id: suinsObjectId,
      options: { showContent: true, showType: true, showOwner: true },
    });

    // Fallback for subnames: use parent domain's NFT if subname NFT doesn't exist
    if (!suinsObject.data && domain.split('.').length > 2) {
      console.debug(`🔍 ${domain} identified as a leaf subname`);
      const parentDomain = domain.split('.').slice(1).join('.');
      const parentRecord = await suinsClient.getNameRecord(parentDomain);
      if (parentRecord?.nftId) {
        suinsObjectId = parentRecord.nftId;
        suinsObject = await client.getObject({
          id: suinsObjectId,
          options: { showContent: true, showType: true, showOwner: true },
        });
      }
    }

    if (!suinsObject.data) {
      console.error(`Failed to fetch SuiNS object for ${domain} (nft_id: ${suinsObjectId})`);
      return result;
    }

    // Extract owner address
    result.owner = suinsObject.data.owner
      ? typeof suinsObject.data.owner === 'string'
        ? suinsObject.data.owner
        : 'AddressOwner' in suinsObject.data.owner
          ? suinsObject.data.owner.AddressOwner
          : null
      : null;

    // Set target from NameRecord or manual resolution
    result.target = targetAddress;
    if (!result.target && defaultToOwner && result.owner) {
      result.target = result.owner; // Fallback to owner if enabled
    }

    // Reverse resolve owner and target
    result.ownerDisplay = result.owner;
    if (result.owner) {
      const ownerName = await resolveReverseName(client, result.owner);
      result.ownerDisplay = ownerName ? `${ownerName} (${shortenAddress(result.owner)})` : shortenAddress(result.owner);
    }
    result.targetDisplay = result.target;
    if (result.target) {
      const targetName = await resolveReverseName(client, result.target);
      result.targetDisplay = targetName ? `${targetName} (${shortenAddress(result.target)})` : shortenAddress(result.target);
    }

    // Step 3: Resolve reg.acct.sui to get the registry address
    const registryRecord = await suinsClient.getNameRecord('reg.acct.sui');
    const registryId = registryRecord?.targetAddress || null;
    console.log(`🔍 reg.acct.sui resolved: ${registryId ? shortenAddress(registryId) : 'null'}`);
    if (!registryId) {
      console.warn('Could not resolve registry address for reg.acct.sui');
      return result;
    }

    // Step 4: Get registry object
    const registry = await client.getObject({
      id: registryId,
      options: { showContent: true },
    });

    const namespacesTableId = (registry.data?.content as any)?.fields?.namespaces?.fields?.id?.id;
    if (!namespacesTableId) {
      console.warn('No namespaces table found in reg.acct.sui');
      return result;
    }

    // Step 5: Find namespace
    const namespaces = await client.getDynamicFields({ parentId: namespacesTableId });
    const nsNamespace = namespaces.data?.find((f: any) => f.name.value === NAMESPACE);
    if (!nsNamespace) {
      console.warn(`Namespace '${NAMESPACE}' not found in ${NETWORK} registry (reg.acct.sui)`);
      return result;
    }

    // Step 6: Get entries table from namespace
    const namespaceObj = await client.getObject({
      id: nsNamespace.objectId,
      options: { showContent: true },
    });

    const entriesTableId = (namespaceObj.data?.content as any)?.fields?.value?.fields?.entries?.fields?.id?.id;
    if (!entriesTableId) {
      console.warn(`No entries table found in ${NETWORK} ${NAMESPACE} namespace`);
      return result;
    }

    // Step 7: Find domain entry in registry
    const entries = await client.getDynamicFields({ parentId: entriesTableId });
    const domainEntry = entries.data?.find((f: any) => f.name.value === domain);

    if (!domainEntry) {
      console.log(`⚠️  AcctObject for ${domain} not found in the ${NETWORK} ${NAMESPACE} namespace`);
      return result;
    }
    console.log(`✅ Success! AcctObject for ${domain} found in the ${NETWORK} ${NAMESPACE} namespace`);

    // Step 8: Get account data from registry
    const accountObj = await client.getObject({
      id: domainEntry.objectId,
      options: { showContent: true },
    });

    result.data = (accountObj.data?.content as any)?.fields?.value?.fields?.data || null;
    if (!result.data) {
      console.warn('No account data found in registry entry');
    }

    return result;
  } catch (error) {
    console.error(`❌ Error fetching data for ${domain}:`, error);
    return result;
  }
}

async function printFormattedAccountData(result: AccountDataResult) {
  console.log('─'.repeat(50));
  console.log(`🔑 Name:   ${result.key}`);
  console.log(`👤 Owner:  ${result.ownerDisplay || `❌ Not owned in ${NETWORK} SuiNS registry`}`);
  console.log(`🎯 Target: ${result.targetDisplay || '❌ No target'}`);
  console.log(`📝 Data:   ${result.data || `⚠️  ${result.key} not registered in the ${NETWORK} ${NAMESPACE} namespace`}`);
  console.log('─'.repeat(50));
}

// Main execution block
if (require.main === module) {
  const args = process.argv.slice(2);
  const domain = args[0];
  const defaultToOwner = args[1] === 'true';

  if (domain) {
    getAccountData(domain, defaultToOwner)
      .then((result) => {
        if (result) {
          printFormattedAccountData(result);
        } else {
          console.log('Query failed or returned no data.');
        }
      })
      .catch((error) => {
        console.error(`Unhandled error: ${error}`);
      });
  } else {
    console.log('Usage: node query-registry.js <domain.sui> [defaultToOwner]');
    console.log('Example: node query-registry.js n-s.acct.sui true');
  }
}