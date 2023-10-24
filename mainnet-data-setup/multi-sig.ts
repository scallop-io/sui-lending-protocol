import { SuiTxBlock } from '@scallop-io/sui-kit';
import { toB64 } from '@mysten/sui.js';
import { suiKit } from 'sui-elements';
export const MULTI_SIG_ADDRESS = '0x1226a80ef40bd2e70c6a285b045b9b5d29915a2c5a2d57a2d3032cbdd89a8d5c';

export async function buildMultiSigTx(tx: SuiTxBlock) {
  tx.setSender(MULTI_SIG_ADDRESS);
  const bytes = await tx.build({ provider: suiKit.provider() });
  const b64 = toB64(bytes);
  return b64;
}
