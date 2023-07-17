import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolWhitelistTxBuilder } from '../contracts/protocol_whitelist';

export const addWhitelist = (tx: SuiTxBlock) => {
  protocolWhitelistTxBuilder.allowAll(tx);
  return tx;
}
