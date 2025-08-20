import { useState } from 'react';
import { UserPlus, ArrowRight, CheckCircle } from 'lucide-react';

interface CreateAccountProps {
  selectedDomain: string;
  domainName: string;
  onRequestCap: () => void;
  onCreateAccount: (capId: string) => void;
  isRequestingCap?: boolean;
  isCreatingAccount?: boolean;
}

export function CreateAccount({
  selectedDomain,
  domainName,
  onRequestCap,
  onCreateAccount,
  isRequestingCap,
  isCreatingAccount,
}: CreateAccountProps) {
  const [step, setStep] = useState<'request' | 'create'>('request');
  const [capId, setCapId] = useState('');

  const handleRequestCap = () => {
    onRequestCap();
    // In a real app, you'd get the cap ID from the transaction result
    // For now, we'll simulate moving to the next step
    setTimeout(() => {
      setStep('create');
    }, 2000);
  };

  const handleCreateAccount = () => {
    if (capId.trim()) {
      onCreateAccount(capId.trim());
    }
  };

  const subdomainName = domainName.replace('.sui', '') + '.nsacct.sui';

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <div className="flex items-center gap-3 mb-6">
        <UserPlus className="w-6 h-6 text-blue-600" />
        <h2 className="text-xl font-semibold">Create Your NS Account</h2>
      </div>

      {/* Progress Indicator */}
      <div className="mb-6">
        <div className="flex items-center gap-4">
          <div className={`
            flex items-center justify-center w-8 h-8 rounded-full text-sm font-medium
            ${step === 'request' || step === 'create' 
              ? 'bg-blue-600 text-white' 
              : 'bg-gray-200 text-gray-600'}
          `}>
            {step === 'create' ? <CheckCircle className="w-4 h-4" /> : '1'}
          </div>
          <div className="flex-1 text-sm text-gray-600">Request Capability</div>
          
          <div className={`
            w-12 h-0.5 
            ${step === 'create' ? 'bg-blue-600' : 'bg-gray-200'}
          `}></div>
          
          <div className={`
            flex items-center justify-center w-8 h-8 rounded-full text-sm font-medium
            ${step === 'create' 
              ? 'bg-blue-600 text-white' 
              : 'bg-gray-200 text-gray-600'}
          `}>
            2
          </div>
          <div className="flex-1 text-sm text-gray-600">Create Account</div>
        </div>
      </div>

      {/* Step Content */}
      {step === 'request' && (
        <div>
          <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <h3 className="font-medium text-blue-900 mb-2">What happens next?</h3>
            <ul className="text-sm text-blue-800 space-y-1">
              <li>• You'll get a capability (SubnameCap) for your domain</li>
              <li>• This proves you own {domainName}</li>
              <li>• Your account will be accessible at <strong>{subdomainName}</strong></li>
              <li>• The account will be permanently linked to your domain</li>
            </ul>
          </div>

          <div className="mb-4">
            <div className="text-sm text-gray-600 mb-2">Domain</div>
            <div className="font-mono text-sm bg-gray-100 p-2 rounded border">
              {domainName}
            </div>
          </div>

          <div className="mb-6">
            <div className="text-sm text-gray-600 mb-2">Future Account Address</div>
            <div className="font-mono text-sm bg-gray-100 p-2 rounded border">
              {subdomainName}
            </div>
          </div>

          <button
            onClick={handleRequestCap}
            disabled={isRequestingCap}
            className="w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white py-3 px-4 rounded-lg transition-colors"
          >
            {isRequestingCap ? (
              <>
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                Requesting Capability...
              </>
            ) : (
              <>
                Request Capability
                <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>
        </div>
      )}

      {step === 'create' && (
        <div>
          <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
            <div className="flex items-center gap-2 text-green-800">
              <CheckCircle className="w-4 h-4" />
              <span className="font-medium">Capability received!</span>
            </div>
            <p className="text-sm text-green-700 mt-1">
              Now let's create your account with subname.
            </p>
          </div>

          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Capability ID
            </label>
            <input
              type="text"
              value={capId}
              onChange={(e) => setCapId(e.target.value)}
              placeholder="Enter the capability object ID from the previous transaction"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              Check the transaction result for the SubnameCap object ID
            </p>
          </div>

          <button
            onClick={handleCreateAccount}
            disabled={isCreatingAccount || !capId.trim()}
            className="w-full flex items-center justify-center gap-2 bg-green-600 hover:bg-green-700 disabled:bg-green-400 text-white py-3 px-4 rounded-lg transition-colors"
          >
            {isCreatingAccount ? (
              <>
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                Creating Account...
              </>
            ) : (
              <>
                Create Account
                <UserPlus className="w-4 h-4" />
              </>
            )}
          </button>
        </div>
      )}
    </div>
  );
}
