import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';

// Constants
const NETWORK = 'testnet';
const NAMESPACE = 'ns';

/**
 * Simple function to query account data from NS registry
 * Usage: node query-registry.js "n-s.acct.sui"
 */
async function getAccountData(domain: string) {
  const client = new SuiClient({ url: getFullnodeUrl(NETWORK) });
  
  try {
    console.log(`🔍 Looking up: ${domain}`);
    
    // Step 1: Get registry from reg.acct.sui
    console.log('📡 Resolving reg.acct.sui...');
    const registryId = await client.resolveNameServiceAddress({ name: "reg.acct.sui" });
    if (!registryId) throw new Error("Could not resolve registry address for reg.acct.sui");
    console.log(`📋 Registry: ${registryId}`);
    
    // Step 2: Get registry object
    const registry = await client.getObject({
      id: registryId,
      options: { showContent: true }
    });
    
    const namespacesTableId = (registry.data?.content as any)?.fields?.namespaces?.fields?.id?.id;
    if (!namespacesTableId) throw new Error("No namespaces table found");
    
    // Step 3: Find namespace
    const namespaces = await client.getDynamicFields({ parentId: namespacesTableId });
    const nsNamespace = namespaces.data?.find((f: any) => f.name.value === NAMESPACE);
    if (!nsNamespace) throw new Error(`Namespace '${NAMESPACE}' not found`);
    
    // Step 4: Get entries table from namespace
    const namespaceObj = await client.getObject({
      id: nsNamespace.objectId,
      options: { showContent: true }
    });
    
    const entriesTableId = (namespaceObj.data?.content as any)?.fields?.value?.fields?.entries?.fields?.id?.id;
    if (!entriesTableId) throw new Error("No entries table found");
    
    // Step 5: Find domain entry
    const entries = await client.getDynamicFields({ parentId: entriesTableId });
    const domainEntry = entries.data?.find((f: any) => f.name.value === domain);
    if (!domainEntry) throw new Error(`AcctObject for '${domain}' not found in the ${NAMESPACE} namespace`);
    
    // Step 6: Get account data
    const accountObj = await client.getObject({
      id: domainEntry.objectId,
      options: { showContent: true }
    });
    
    const accountData = (accountObj.data?.content as any)?.fields?.value?.fields;
    if (!accountData) throw new Error("No account data found");
    
    // Display results
    console.log('\n✅ SUCCESS!');
    console.log('─'.repeat(50));
    console.log(`🔑 Key:    ${accountData.key}`);
    console.log(`📝 Data:   ${accountData.data}`);
    console.log(`👤 Owner:  ${accountData.owner}`);
    console.log(`🎯 Target: ${accountData.target}`);
    console.log(`🆔 Object: ${domainEntry.objectId}`);
    console.log('─'.repeat(50));
    
    return accountData;
    
  } catch (error) {
    console.error(`❌ ${error}`);
    return null;
  }
}

/**
 * List all domains in the registry
 */
async function listDomains() {
  const client = new SuiClient({ url: getFullnodeUrl(NETWORK) });
  
  try {
    console.log('📋 Listing all domains...');
    
    const registryId = await client.resolveNameServiceAddress({ name: "reg.acct.sui" });
    if (!registryId) throw new Error("Could not resolve registry address for reg.acct.sui");
    const registry = await client.getObject({
      id: registryId,
      options: { showContent: true }
    });
    
    const namespacesTableId = (registry.data?.content as any)?.fields?.namespaces?.fields?.id?.id;
    const namespaces = await client.getDynamicFields({ parentId: namespacesTableId });
    const nsNamespace = namespaces.data?.find((f: any) => f.name.value === NAMESPACE);
    
    if (!nsNamespace) {
      console.log(`❌ Namespace '${NAMESPACE}' not found`);
      return [];
    }
    
    const namespaceObj = await client.getObject({
      id: nsNamespace.objectId,
      options: { showContent: true }
    });
    
    const entriesTableId = (namespaceObj.data?.content as any)?.fields?.value?.fields?.entries?.fields?.id?.id;
    const entries = await client.getDynamicFields({ parentId: entriesTableId });
    
    const domains = entries.data?.map((f: any) => f.name.value) || [];
    
    console.log('\n📋 Available domains:');
    domains.forEach((domain: string) => console.log(`  • ${domain}`));
    
    return domains;
    
  } catch (error) {
    console.error(`❌ ${error}`);
    return [];
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage:');
    console.log('  Query domain:    bun query-registry.ts "n-s.acct.sui"');
    console.log('  List all:        bun query-registry.ts --list');
    return;
  }
  
  if (args[0] === '--list') {
    await listDomains();
  } else {
    await getAccountData(args[0]);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

// Export for use in other files
export { getAccountData, listDomains };
