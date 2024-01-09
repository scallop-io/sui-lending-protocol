import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder, InterestModel } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { interestModels } from './interest-models';

function updateInterestModels() {
  const tx = new SuiTxBlock();
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.sui, interestModel: interestModels.sui },
    { type: coinTypes.cetus, interestModel: interestModels.cetus },
    { type: coinTypes.wormholeUsdc, interestModel: interestModels.wormholeUsdc },
    { type: coinTypes.wormholeUsdt, interestModel: interestModels.wormholeUsdt },
    { type: coinTypes.wormholeEth, interestModel: interestModels.wormholeEth },
    { type: coinTypes.afSui, interestModel: interestModels.afSui },
    { type: coinTypes.haSui, interestModel: interestModels.haSui },
    { type: coinTypes.vSui, interestModel: interestModels.vSui },
  ];
  for(const pair of interestModelPairs) {
    protocolTxBuilder.updateInterestModel(tx, pair.interestModel, pair.type);
  }
  return buildMultiSigTx(tx);
}

updateInterestModels().then(console.log);