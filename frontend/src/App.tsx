import { useState } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useWallet } from '@suiet/wallet-kit';
import { WalletProviderWrapper, ConnectWallet } from './components/ConnectWallet';
import { DomainSelector } from './components/DomainSelector';
import { CreateAccount } from './components/CreateAccount';
import { AccountDashboard } from './components/AccountDashboard';
import { useNSAcct } from './hooks/useNSAcct';
import { Globe } from 'lucide-react';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      refetchOnWindowFocus: false,
    },
  },
});

function AppContent() {
  const { connected } = useWallet();
  const [selectedDomain, setSelectedDomain] = useState<string | null>(null);
  
  const {
    userDomains,
    nsAccount,
    domainsLoading,
    accountLoading,
    requestCap,
    createAccount,
    updateValue,
    addField,
    deleteField,
    isRequestingCap,
    isCreatingAccount,
    isUpdatingValue,
    isAddingField,
    isDeletingField,
  } = useNSAcct();

  if (!connected) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full">
          <div className="text-center mb-8">
            <Globe className="w-16 h-16 text-blue-600 mx-auto mb-4" />
            <h1 className="text-3xl font-bold text-gray-900 mb-2">NS Acct</h1>
            <p className="text-gray-600">
              Domain-based accounts on Sui. Own a .sui domain, get a permanent account.
            </p>
          </div>
          <ConnectWallet />
        </div>
      </div>
    );
  }

  const selectedDomainData = userDomains.find(d => d.id === selectedDomain);

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-4xl mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Globe className="w-8 h-8 text-blue-600" />
              <div>
                <h1 className="text-2xl font-bold text-gray-900">NS Acct</h1>
                <p className="text-sm text-gray-600">Domain-based accounts on Sui</p>
              </div>
            </div>
            <ConnectWallet />
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 py-8">
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Left Column - Domain Selection */}
          <div>
            <DomainSelector
              domains={userDomains}
              selectedDomain={selectedDomain}
              onSelectDomain={setSelectedDomain}
              isLoading={domainsLoading}
            />
          </div>

          {/* Right Column - Account Management */}
          <div>
            {!selectedDomain ? (
              <div className="bg-white border border-gray-200 rounded-lg p-6 text-center">
                <h3 className="text-lg font-medium text-gray-600 mb-2">
                  Select a domain to continue
                </h3>
                <p className="text-sm text-gray-500">
                  Choose one of your .sui domains to create or manage your NS account
                </p>
              </div>
            ) : accountLoading ? (
              <div className="bg-white border border-gray-200 rounded-lg p-6">
                <div className="animate-pulse">
                  <div className="h-6 bg-gray-200 rounded w-3/4 mb-4"></div>
                  <div className="h-4 bg-gray-200 rounded w-1/2 mb-2"></div>
                  <div className="h-4 bg-gray-200 rounded w-2/3"></div>
                </div>
              </div>
            ) : nsAccount ? (
              <AccountDashboard
                account={nsAccount}
                domainId={selectedDomain}
                onUpdateValue={updateValue}
                onAddField={addField}
                onDeleteField={deleteField}
                isUpdatingValue={isUpdatingValue}
                isAddingField={isAddingField}
                isDeletingField={isDeletingField}
              />
            ) : (
              <CreateAccount
                selectedDomain={selectedDomain}
                domainName={selectedDomainData?.name || ''}
                onRequestCap={() => requestCap(selectedDomain)}
                onCreateAccount={(capId) => createAccount({ domainId: selectedDomain, capId })}
                isRequestingCap={isRequestingCap}
                isCreatingAccount={isCreatingAccount}
              />
            )}
          </div>
        </div>

        {/* Footer */}
        <footer className="mt-12 pt-8 border-t border-gray-200 text-center text-sm text-gray-500">
          <p>
            Built with ❤️ for the Sui ecosystem. 
            <a href="https://suins.io" className="text-blue-600 hover:text-blue-700 ml-1">
              Powered by SuiNS
            </a>
          </p>
        </footer>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <WalletProviderWrapper>
        <AppContent />
      </WalletProviderWrapper>
    </QueryClientProvider>
  );
}
