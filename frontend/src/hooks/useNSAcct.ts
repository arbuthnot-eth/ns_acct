import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Transaction } from '@mysten/sui.js/transactions';
import { useWallet } from '@suiet/wallet-kit';
import { useSuiClient } from './useSuiClient';
import { 
  PACKAGE_ID, 
  PARENT_WRAPPER_ID, 
  FUNCTIONS, 
  GAS_BUDGET,
  ERROR_MESSAGES 
} from '../config/constants';

// Types
export interface NSAcctData {
  id: string;
  regId: string;
  value: number;
  extraFields: Record<string, string>;
}

export interface UserDomain {
  id: string;
  name: string;
  domain: string;
}

export function useNSAcct() {
  const suiClient = useSuiClient();
  const { account, signAndExecuteTransaction } = useWallet();
  const queryClient = useQueryClient();

  // Query user's domains
  const { data: userDomains, isLoading: domainsLoading } = useQuery({
    queryKey: ['userDomains', account?.address],
    queryFn: async (): Promise<UserDomain[]> => {
      if (!account?.address) return [];

      // Query SuiNS registrations owned by user
      const ownedObjects = await suiClient.getOwnedObjects({
        owner: account.address,
        filter: {
          StructType: `${PACKAGE_ID}::suins_registration::SuinsRegistration`
        },
        options: {
          showContent: true,
          showType: true,
        }
      });

      return ownedObjects.data.map(obj => ({
        id: obj.data?.objectId || '',
        name: extractDomainName(obj.data?.content || {}),
        domain: extractDomainName(obj.data?.content || {}),
      })).filter(domain => domain.name.endsWith('.sui'));
    },
    enabled: !!account?.address,
  });

  // Query user's NS account
  const { data: nsAccount, isLoading: accountLoading } = useQuery({
    queryKey: ['nsAccount', account?.address],
    queryFn: async (): Promise<NSAcctData | null> => {
      if (!account?.address) return null;

      // Find accounts created by this user
      const ownedObjects = await suiClient.getOwnedObjects({
        owner: account.address,
        filter: {
          StructType: `${PACKAGE_ID}::ns_acct::Acct`
        },
        options: {
          showContent: true,
        }
      });

      if (ownedObjects.data.length === 0) return null;

      const acct = ownedObjects.data[0];
      const content = acct.data?.content as any;

      return {
        id: acct.data?.objectId || '',
        regId: content?.fields?.reg_id || '',
        value: parseInt(content?.fields?.value || '0'),
        extraFields: parseExtraFields(content?.fields?.extra_fields || {}),
      };
    },
    enabled: !!account?.address,
  });

  // Request capability mutation
  const requestCapMutation = useMutation({
    mutationFn: async (domainId: string) => {
      if (!account?.address) throw new Error(ERROR_MESSAGES.NO_WALLET);

      const tx = new Transaction();
      tx.moveCall({
        target: `${PACKAGE_ID}::ns_acct::${FUNCTIONS.REQUEST_CAP}`,
        arguments: [
          tx.object(domainId),
        ],
      });

      const result = await signAndExecuteTransaction({
        transaction: tx,
        options: {
          showEffects: true,
          showObjectChanges: true,
        },
      });

      return result;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['userCapabilities'] });
    },
  });

  // Create account with subname mutation
  const createAccountMutation = useMutation({
    mutationFn: async ({ domainId, capId }: { domainId: string; capId: string }) => {
      if (!account?.address) throw new Error(ERROR_MESSAGES.NO_WALLET);

      const tx = new Transaction();
      
      // Get clock object
      tx.moveCall({
        target: `${PACKAGE_ID}::ns_acct::${FUNCTIONS.CREATE_WITH_SUBNAME}`,
        arguments: [
          tx.object('0x6'), // SuiNS object (shared)
          tx.object(domainId),
          tx.object(PARENT_WRAPPER_ID),
          tx.object(capId),
          tx.object('0x6'), // Clock object
        ],
      });

      const result = await signAndExecuteTransaction({
        transaction: tx,
        options: {
          showEffects: true,
          showObjectChanges: true,
        },
      });

      return result;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['nsAccount'] });
    },
  });

  // Update value mutation
  const updateValueMutation = useMutation({
    mutationFn: async ({ domainId, accountId, newValue }: { 
      domainId: string; 
      accountId: string; 
      newValue: number;
    }) => {
      if (!account?.address) throw new Error(ERROR_MESSAGES.NO_WALLET);

      const tx = new Transaction();
      tx.moveCall({
        target: `${PACKAGE_ID}::ns_acct::${FUNCTIONS.UPDATE_VALUE}`,
        arguments: [
          tx.object(domainId),
          tx.object(accountId),
          tx.pure.u64(newValue),
        ],
      });

      const result = await signAndExecuteTransaction({
        transaction: tx,
        options: {
          showEffects: true,
        },
      });

      return result;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['nsAccount'] });
    },
  });

  // Add field mutation
  const addFieldMutation = useMutation({
    mutationFn: async ({ 
      domainId, 
      accountId, 
      key, 
      value 
    }: { 
      domainId: string; 
      accountId: string; 
      key: string; 
      value: string;
    }) => {
      if (!account?.address) throw new Error(ERROR_MESSAGES.NO_WALLET);

      const tx = new Transaction();
      tx.moveCall({
        target: `${PACKAGE_ID}::ns_acct::${FUNCTIONS.ADD_FIELD}`,
        arguments: [
          tx.object(domainId),
          tx.object(accountId),
          tx.pure.string(key),
          tx.pure.string(value),
        ],
      });

      const result = await signAndExecuteTransaction({
        transaction: tx,
        options: {
          showEffects: true,
        },
      });

      return result;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['nsAccount'] });
    },
  });

  // Delete field mutation
  const deleteFieldMutation = useMutation({
    mutationFn: async ({ 
      domainId, 
      accountId, 
      key 
    }: { 
      domainId: string; 
      accountId: string; 
      key: string;
    }) => {
      if (!account?.address) throw new Error(ERROR_MESSAGES.NO_WALLET);

      const tx = new Transaction();
      tx.moveCall({
        target: `${PACKAGE_ID}::ns_acct::${FUNCTIONS.DELETE_FIELD}`,
        arguments: [
          tx.object(domainId),
          tx.object(accountId),
          tx.pure.string(key),
        ],
      });

      const result = await signAndExecuteTransaction({
        transaction: tx,
        options: {
          showEffects: true,
        },
      });

      return result;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['nsAccount'] });
    },
  });

  return {
    // Data
    userDomains: userDomains || [],
    nsAccount,
    
    // Loading states
    domainsLoading,
    accountLoading,
    
    // Mutations
    requestCap: requestCapMutation.mutate,
    createAccount: createAccountMutation.mutate,
    updateValue: updateValueMutation.mutate,
    addField: addFieldMutation.mutate,
    deleteField: deleteFieldMutation.mutate,
    
    // Mutation states
    isRequestingCap: requestCapMutation.isPending,
    isCreatingAccount: createAccountMutation.isPending,
    isUpdatingValue: updateValueMutation.isPending,
    isAddingField: addFieldMutation.isPending,
    isDeletingField: deleteFieldMutation.isPending,
  };
}

// Helper functions
function extractDomainName(content: any): string {
  // Extract domain name from SuinsRegistration content
  // This will need to be adapted based on actual SuiNS structure
  return content?.fields?.domain?.fields?.name || '';
}

function parseExtraFields(fieldsData: any): Record<string, string> {
  // Parse VecMap structure to plain object
  if (!fieldsData?.fields?.contents) return {};
  
  const result: Record<string, string> = {};
  const contents = fieldsData.fields.contents;
  
  if (Array.isArray(contents)) {
    contents.forEach((item: any) => {
      if (item.fields && item.fields.key && item.fields.value) {
        result[item.fields.key] = item.fields.value;
      }
    });
  }
  
  return result;
}
