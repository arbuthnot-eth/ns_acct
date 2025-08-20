import { Globe, Plus } from 'lucide-react';
import { UserDomain } from '../hooks/useNSAcct';

interface DomainSelectorProps {
  domains: UserDomain[];
  selectedDomain: string | null;
  onSelectDomain: (domainId: string) => void;
  isLoading?: boolean;
}

export function DomainSelector({ 
  domains, 
  selectedDomain, 
  onSelectDomain, 
  isLoading 
}: DomainSelectorProps) {
  if (isLoading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-4">
          <Globe className="w-5 h-5 text-blue-600" />
          <h3 className="text-lg font-semibold">Your .sui Domains</h3>
        </div>
        <div className="animate-pulse">
          <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
          <div className="h-4 bg-gray-200 rounded w-1/2"></div>
        </div>
      </div>
    );
  }

  if (domains.length === 0) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-4">
          <Globe className="w-5 h-5 text-blue-600" />
          <h3 className="text-lg font-semibold">Your .sui Domains</h3>
        </div>
        <div className="text-center py-8">
          <Globe className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h4 className="text-lg font-medium text-gray-600 mb-2">
            No .sui domains found
          </h4>
          <p className="text-sm text-gray-500 mb-4">
            You need to own a .sui domain to create an NS account
          </p>
          <a
            href="https://suins.io"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors"
          >
            <Plus className="w-4 h-4" />
            Register a domain
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <div className="flex items-center gap-3 mb-4">
        <Globe className="w-5 h-5 text-blue-600" />
        <h3 className="text-lg font-semibold">Your .sui Domains</h3>
      </div>
      
      <div className="space-y-2">
        {domains.map((domain) => (
          <div
            key={domain.id}
            className={`
              p-3 rounded-lg border cursor-pointer transition-all
              ${selectedDomain === domain.id
                ? 'border-blue-500 bg-blue-50 ring-2 ring-blue-500 ring-opacity-20'
                : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'
              }
            `}
            onClick={() => onSelectDomain(domain.id)}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="font-medium text-gray-900">{domain.name}</div>
                <div className="text-sm text-gray-500">
                  ID: {domain.id.slice(0, 8)}...{domain.id.slice(-4)}
                </div>
              </div>
              {selectedDomain === domain.id && (
                <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
              )}
            </div>
          </div>
        ))}
      </div>
      
      <div className="mt-4 pt-4 border-t border-gray-200">
        <a
          href="https://suins.io"
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-blue-600 hover:text-blue-700 flex items-center gap-1"
        >
          <Plus className="w-4 h-4" />
          Register another domain
        </a>
      </div>
    </div>
  );
}
