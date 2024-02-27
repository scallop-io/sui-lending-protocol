import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { afSuiRiskModel, suiRiskModel, wormholeEthRiskModel, wormholeUsdcRiskModel, wormholeUsdtRiskModel } from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  // update the risk model for 'sui'
  protocolTxBuilder.updateRiskModel(tx, afSuiRiskModel, coinTypes.afSui);
  protocolTxBuilder.updateRiskModel(tx, suiRiskModel, coinTypes.sui);
  protocolTxBuilder.updateRiskModel(tx, wormholeUsdtRiskModel, coinTypes.wormholeUsdt);
  protocolTxBuilder.updateRiskModel(tx, wormholeUsdcRiskModel, coinTypes.wormholeUsdc);
  protocolTxBuilder.updateRiskModel(tx, wormholeEthRiskModel, coinTypes.wormholeEth);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);