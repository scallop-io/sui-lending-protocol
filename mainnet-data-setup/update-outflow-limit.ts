import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import {
  outflowRateLimiters,
} from './outflow-rate-limiters';

function updateOutflowLimits() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.deep, coinTypes.deep);
  return buildMultiSigTx(tx);
}

updateOutflowLimits().then(console.log);