import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolWhitelistTxBuilder } from '../contracts/protocol_whitelist';
import {suiKit} from "../sui-elements";

export const addWhitelist = (tx: SuiTxBlock) => {
  protocolWhitelistTxBuilder.allowAll(tx);
  return tx;
}
const tx = new SuiTxBlock();
addWhitelist(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error).finally(() => process.exit(0));
