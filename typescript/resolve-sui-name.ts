import { SuiClient } from '@mysten/sui/client';

// Constants
const SUINS_PACKAGE_ID = '0x22fa05f21b1ad71442491220bb9338f7b7095fe35000ef88d5400d28523bdd93';
const SUINS_REGISTRY_ID = '0xb120c0d55432630fce61f7854795a3463deb6e3b443cc4ae72e1282073ff56e4';

interface SuiNameResult {
  objectId: string | null;
  isSubname: boolean;
  subname?: string;
}

// Function to resolve a SuiNS name or leaf subname to its SuinsRegistration object ID
export async function resolveSuiName(client: SuiClient, name: string): Promise<SuiNameResult> {
  try {
    // Split name to detect subname (e.g., "n-s.acct.sui" → ["n-s", "acct", "sui"])
    const labels = name.split('.');
    const isSubname = labels.length > 2;
    const parentName = isSubname ? labels.slice(1).join('.') : name; // e.g., "acct.sui"
    const subname = isSubname ? labels[0] : undefined; // e.g., "n-s"

    // Resolve parent name in the SuiNS registry
    const response = await client.getDynamicFieldObject({
      parentId: SUINS_REGISTRY_ID,
      name: {
        type: `${SUINS_PACKAGE_ID}::domain::Domain`,
        value: {
          labels: parentName.split('.').reverse(), // e.g., ["sui", "acct"]
        },
      },
    });

    if (!response.data) {
      return { objectId: null, isSubname, subname };
    }

    const fields = (response.data.content as any)?.fields;
    const nftId = fields?.value?.fields?.nft_id;
    if (!nftId) {
      return { objectId: null, isSubname, subname };
    }

    return { objectId: nftId, isSubname, subname };
  } catch (error) {
    return { objectId: null, isSubname: name.split('.').length > 2, subname: name.split('.')[0] };
  }
}