import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import {
  riskModels,
} from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.updateRiskModel(tx, riskModels.afSui, coinTypes.afSui);
  protocolTxBuilder.updateRiskModel(tx, riskModels.haSui, coinTypes.haSui);
  protocolTxBuilder.updateRiskModel(tx, riskModels.vSui, coinTypes.vSui);
  protocolTxBuilder.updateRiskModel(tx, riskModels.wormholeSol, coinTypes.wormholeSol);
  protocolTxBuilder.updateRiskModel(tx, riskModels.wormholeBtc, coinTypes.wormholeBtc);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);
