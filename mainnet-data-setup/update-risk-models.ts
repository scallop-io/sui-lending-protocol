import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import {
  riskModels,
} from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  // update the risk model for 'hasui'
  protocolTxBuilder.updateRiskModel(tx, riskModels.haSui, coinTypes.haSui);
  protocolTxBuilder.updateRiskModel(tx, riskModels.afSui, coinTypes.afSui);
  protocolTxBuilder.updateRiskModel(tx, riskModels.sca, coinTypes.sca);
  protocolTxBuilder.updateRiskModel(tx, riskModels.wormholeEth, coinTypes.wormholeEth);
  protocolTxBuilder.updateRiskModel(tx, riskModels.wormholeUsdt, coinTypes.wormholeUsdt);
  protocolTxBuilder.updateRiskModel(tx, riskModels.wormholeUsdc, coinTypes.wormholeUsdc);
  protocolTxBuilder.updateRiskModel(tx, riskModels.sui, coinTypes.sui);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);
