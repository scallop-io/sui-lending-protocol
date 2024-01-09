import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { buildMultiSigTx } from "./multi-sig";

incrementProtocolVersion().then(console.log).catch(console.error).finally(() => process.exit(0));
function incrementProtocolVersion() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.incrementVersion(tx);

  return buildMultiSigTx(tx);
}
