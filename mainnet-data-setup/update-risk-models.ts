import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { afSuiRiskModel, haSuiRiskModel, suiRiskModel, wormholeEthRiskModel, wormholeUsdcRiskModel, wormholeUsdtRiskModel } from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  // update the risk model for 'hasui'
  protocolTxBuilder.updateRiskModel(tx, haSuiRiskModel, coinTypes.haSui);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);