import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { afSuiRiskModel } from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  // update the risk model for 'sui'
  protocolTxBuilder.updateRiskModel(tx, afSuiRiskModel, coinTypes.afSui);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);