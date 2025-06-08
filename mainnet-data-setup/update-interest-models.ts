import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder, InterestModel } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { interestModels } from './interest-models';

function updateInterestModels() {
  const tx = new SuiTxBlock();
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.sca, interestModel: interestModels.sca },
  ];
  for(const pair of interestModelPairs) {
    protocolTxBuilder.updateInterestModel(tx, pair.interestModel, pair.type);
  }
  return buildMultiSigTx(tx);
}

updateInterestModels().then(console.log);