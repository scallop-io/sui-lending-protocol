import { SuiTxBlock, toBase64 } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
export const MULTI_SIG_ADDRESS = '0x4f8744837e95c79258a23ea6dc1985dcbbd39935a49b75e3d43a4427ff5f5cb4';

export async function buildMultiSigTx(tx: SuiTxBlock) {
  tx.setSender(MULTI_SIG_ADDRESS);
  const bytes = await tx.build({ client: suiKit.client() });
  const b64 = toBase64(bytes);
  return b64;
}
