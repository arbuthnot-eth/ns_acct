import { SuiClient } from '@mysten/sui/client';
import { resolveSuiName } from './resolve-sui-name';

// Constants
const NETWORK = 'testnet';
const NAMESPACE = 'ns';
interface AccountDataResult {
  key: string;
  data: any | null;
  target: string | null;
  owner: string | null;
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

/**
 * Queries account data from SuiNS and the reg.acct.sui registry
 * Usage: node query-registry.js "n-s.acct.sui" [defaultToOwner]
 * @param domain The SuiNS domain to query (e.g., "n-s.acct.sui")
 * @param defaultToOwner If true, use owner address as target when target is null
 */
async function getAccountData(domain: string, defaultToOwner: boolean = false) {
  const result: AccountDataResult = {
    key: domain,
    data: null,
    target: null,
    owner: null,
  };

  const client = new SuiClient({ url: await getRPC_URL(NETWORK) });

  try {
    // Step 1: Resolve SuiNS name or subname
    const { objectId: suinsObjectId, isSubname, subname } = await resolveSuiName(client, domain);

    if (!suinsObjectId) {
      console.log(`⚠️  Domain '${domain}' is not registered in SuiNS ${NETWORK} registry`);
      return result;
    }
    console.log(`✅ Success! ${domain} is registered in SuiNS ${NETWORK} registry`);

    // Step 2: Fetch SuiNS object details (parent's SuinsRegistration)
    const suinsObject = await client.getObject({
      id: suinsObjectId,
      options: {
        showContent: true,
        showType: true,
        showOwner: true,
        showPreviousTransaction: true,
      },
    });

    if (!suinsObject.data) {
      console.error(`Failed to fetch SuiNS object for ${domain}`);
      return result;
    }

    // Safely extract owner address
    result.owner = suinsObject.data.owner
      ? typeof suinsObject.data.owner === 'string'
        ? suinsObject.data.owner
        : 'AddressOwner' in suinsObject.data.owner
          ? suinsObject.data.owner.AddressOwner
          : null
      : null;

    // Fetch target address for parent or subname
    result.target = await client.resolveNameServiceAddress({ name: isSubname ? domain.split('.').slice(1).join('.') : domain });
    if (!result.target && isSubname) {
      // For subnames, check dynamic fields for target_address
      const subnameFields = await client.getDynamicFields({ parentId: suinsObjectId });
      const subnameEntry = subnameFields.data?.find((f: any) => f.name.value === subname);
      if (subnameEntry) {
        const subnameObj = await client.getObject({
          id: subnameEntry.objectId,
          options: { showContent: true },
        });
        result.target = (subnameObj.data?.content as any)?.fields?.target_address || null;
      }
    }
    if (!result.target && defaultToOwner && result.owner) {
      result.target = result.owner; // Fallback to owner if enabled
    }

    // Step 3: Resolve reg.acct.sui to get the registry address
    const registryId = await client.resolveNameServiceAddress({ name: 'reg.acct.sui' });
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

async function printFormattedAccountData(result: any) {
  console.log('─'.repeat(50));
  console.log(`🔑 Name:   ${result.key}`);
  console.log(`👤 Owner:  ${result.owner || `⚠️  Not owned in ${NETWORK} SuiNS registry`}`);
  console.log(`🎯 Target: ${result.target || '⚠️  No target'}`);
  console.log(`📝 Data:   ${result.data || `⚠️  Not registered in the ${NETWORK} ${NAMESPACE} namespace of the acct registry`}`);
  console.log('─'.repeat(50));
}

// Main execution block
if (require.main === module) {
  const args = process.argv.slice(2);
  const domain = args[0];
  const defaultToOwner = args[1] === 'true'; // Optional: node query-registry.js n-s.acct.sui true

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