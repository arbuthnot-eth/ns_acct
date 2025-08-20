import { WalletProvider, ConnectButton, useWallet } from '@suiet/wallet-kit';
import { Wallet } from 'lucide-react';

export function WalletProviderWrapper({ children }: { children: React.ReactNode }) {
  return (
    <WalletProvider>
      {children}
    </WalletProvider>
  );
}

export function ConnectWallet() {
  const { connected, account } = useWallet();

  if (connected && account) {
    return (
      <div className="flex items-center gap-3 bg-green-50 border border-green-200 rounded-lg px-4 py-2">
        <div className="w-2 h-2 bg-green-500 rounded-full"></div>
        <span className="text-sm text-green-700">
          Connected: {account.address.slice(0, 6)}...{account.address.slice(-4)}
        </span>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-4 p-6 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
      <Wallet className="w-12 h-12 text-gray-400" />
      <div className="text-center">
        <h3 className="text-lg font-semibold text-gray-700 mb-2">
          Connect Your Wallet
        </h3>
        <p className="text-sm text-gray-500 mb-4">
          Connect your Sui wallet to access your domain-based account
        </p>
        <ConnectButton className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg transition-colors">
          Connect Wallet
        </ConnectButton>
      </div>
    </div>
  );
}
