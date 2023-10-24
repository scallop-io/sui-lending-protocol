import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { suiRiskModel } from './risk-models';

function updateRiskModels() {
  const tx = new SuiTxBlock();
  // update the risk model for 'sui'
  protocolTxBuilder.updateRiskModel(tx, suiRiskModel, coinTypes.sui);
  return buildMultiSigTx(tx);
}

updateRiskModels().then(console.log);