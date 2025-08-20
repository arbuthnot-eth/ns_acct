import { useState } from 'react';
import { User, Hash, Plus, Trash2, Edit3, Save, X } from 'lucide-react';
import { NSAcctData } from '../hooks/useNSAcct';

interface AccountDashboardProps {
  account: NSAcctData;
  domainId: string;
  onUpdateValue: (newValue: number) => void;
  onAddField: (key: string, value: string) => void;
  onDeleteField: (key: string) => void;
  isUpdatingValue?: boolean;
  isAddingField?: boolean;
  isDeletingField?: boolean;
}

export function AccountDashboard({
  account,
  domainId,
  onUpdateValue,
  onAddField,
  onDeleteField,
  isUpdatingValue,
  isAddingField,
  isDeletingField,
}: AccountDashboardProps) {
  const [editingValue, setEditingValue] = useState(false);
  const [newValue, setNewValue] = useState(account.value.toString());
  const [showAddField, setShowAddField] = useState(false);
  const [newFieldKey, setNewFieldKey] = useState('');
  const [newFieldValue, setNewFieldValue] = useState('');

  const handleUpdateValue = () => {
    const numValue = parseInt(newValue);
    if (!isNaN(numValue)) {
      onUpdateValue(numValue);
      setEditingValue(false);
    }
  };

  const handleAddField = () => {
    if (newFieldKey.trim() && newFieldValue.trim()) {
      onAddField(newFieldKey.trim(), newFieldValue.trim());
      setNewFieldKey('');
      setNewFieldValue('');
      setShowAddField(false);
    }
  };

  const extraFieldEntries = Object.entries(account.extraFields);

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <div className="flex items-center gap-3 mb-6">
        <User className="w-6 h-6 text-green-600" />
        <h2 className="text-xl font-semibold">Your NS Account</h2>
      </div>

      {/* Account ID */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <div className="flex items-center gap-2 mb-2">
          <Hash className="w-4 h-4 text-gray-500" />
          <span className="text-sm font-medium text-gray-700">Account ID</span>
        </div>
        <div className="font-mono text-sm text-gray-600 break-all">
          {account.id}
        </div>
      </div>

      {/* Value Field */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-lg font-medium">Value</h3>
          {!editingValue && (
            <button
              onClick={() => setEditingValue(true)}
              className="text-blue-600 hover:text-blue-700 p-1"
            >
              <Edit3 className="w-4 h-4" />
            </button>
          )}
        </div>
        
        {editingValue ? (
          <div className="flex gap-2">
            <input
              type="number"
              value={newValue}
              onChange={(e) => setNewValue(e.target.value)}
              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Enter new value"
            />
            <button
              onClick={handleUpdateValue}
              disabled={isUpdatingValue}
              className="px-4 py-2 bg-green-600 hover:bg-green-700 disabled:bg-green-400 text-white rounded-lg transition-colors flex items-center gap-1"
            >
              <Save className="w-4 h-4" />
              {isUpdatingValue ? 'Saving...' : 'Save'}
            </button>
            <button
              onClick={() => {
                setEditingValue(false);
                setNewValue(account.value.toString());
              }}
              className="px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        ) : (
          <div className="text-2xl font-bold text-gray-900">
            {account.value}
          </div>
        )}
      </div>

      {/* Extra Fields */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-lg font-medium">Custom Fields</h3>
          <button
            onClick={() => setShowAddField(true)}
            className="text-blue-600 hover:text-blue-700 p-1 flex items-center gap-1"
          >
            <Plus className="w-4 h-4" />
            Add Field
          </button>
        </div>

        {/* Add Field Form */}
        {showAddField && (
          <div className="mb-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex gap-2 mb-2">
              <input
                type="text"
                value={newFieldKey}
                onChange={(e) => setNewFieldKey(e.target.value)}
                placeholder="Field name (e.g., bio, twitter)"
                className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <input
                type="text"
                value={newFieldValue}
                onChange={(e) => setNewFieldValue(e.target.value)}
                placeholder="Field value"
                className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={handleAddField}
                disabled={isAddingField || !newFieldKey.trim() || !newFieldValue.trim()}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white rounded-lg transition-colors"
              >
                {isAddingField ? 'Adding...' : 'Add Field'}
              </button>
              <button
                onClick={() => {
                  setShowAddField(false);
                  setNewFieldKey('');
                  setNewFieldValue('');
                }}
                className="px-4 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* Fields List */}
        {extraFieldEntries.length === 0 ? (
          <div className="text-center py-8 text-gray-500">
            <div className="text-lg mb-2">No custom fields yet</div>
            <div className="text-sm">Add some metadata to personalize your account</div>
          </div>
        ) : (
          <div className="space-y-2">
            {extraFieldEntries.map(([key, value]) => (
              <div key={key} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex-1">
                  <div className="font-medium text-gray-900">{key}</div>
                  <div className="text-sm text-gray-600">{value}</div>
                </div>
                <button
                  onClick={() => onDeleteField(key)}
                  disabled={isDeletingField}
                  className="text-red-600 hover:text-red-700 disabled:text-red-400 p-1"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
