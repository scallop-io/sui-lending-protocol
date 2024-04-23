import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import {
  outflowRateLimiters,
} from './outflow-rate-limiters';

function updateOutflowLimits() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.haSui, coinTypes.haSui);
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.afSui, coinTypes.afSui);
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.sca, coinTypes.sca);
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.wormholeEth, coinTypes.wormholeEth);
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.wormholeUsdt, coinTypes.wormholeUsdt);
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.wormholeUsdc, coinTypes.wormholeUsdc);
  protocolTxBuilder.updateOutflowLimit(tx, outflowRateLimiters.sui, coinTypes.sui);
  return buildMultiSigTx(tx);
}

updateOutflowLimits().then(console.log);