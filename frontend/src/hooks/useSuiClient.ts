import { SuiClient } from '@mysten/sui.js/client';
import { useMemo } from 'react';
import { RPC_URL } from '../config/constants';

export function useSuiClient() {
  return useMemo(() => new SuiClient({ url: RPC_URL }), []);
}
