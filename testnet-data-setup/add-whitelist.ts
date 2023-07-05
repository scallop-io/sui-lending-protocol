import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolWhitelistTxBuilder } from '../contracts/protocol_whitelist';

export const whiteListAllowAll = (txBlock: SuiTxBlock) => {
  protocolWhitelistTxBuilder.allowAll(txBlock);
}
