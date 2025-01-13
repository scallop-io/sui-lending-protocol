import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder, InterestModel } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { interestModels } from './interest-models';

function updateInterestModels() {
  const tx = new SuiTxBlock();
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.sui, interestModel: interestModels.sui },
    { type: coinTypes.sca, interestModel: interestModels.sca },
    { type: coinTypes.cetus, interestModel: interestModels.cetus },
    { type: coinTypes.wormholeUsdc, interestModel: interestModels.wormholeUsdc },
    { type: coinTypes.nativeUsdc, interestModel: interestModels.nativeUsdc },
    { type: coinTypes.wormholeUsdt, interestModel: interestModels.wormholeUsdt },
    { type: coinTypes.sbUsdt, interestModel: interestModels.sbUsdt },
    { type: coinTypes.fdusd, interestModel: interestModels.fdusd },
    { type: coinTypes.wormholeEth, interestModel: interestModels.wormholeEth },
    { type: coinTypes.sbEth, interestModel: interestModels.sbEth },
    { type: coinTypes.wormholeSol, interestModel: interestModels.wormholeSol },
    { type: coinTypes.wormholeBtc, interestModel: interestModels.wormholeBtc },
    { type: coinTypes.afSui, interestModel: interestModels.afSui },
    { type: coinTypes.haSui, interestModel: interestModels.haSui },
    { type: coinTypes.vSui, interestModel: interestModels.vSui },
    { type: coinTypes.deep, interestModel: interestModels.deep },
    { type: coinTypes.fud, interestModel: interestModels.fud },
  ];
  for(const pair of interestModelPairs) {
    protocolTxBuilder.updateInterestModel(tx, pair.interestModel, pair.type);
  }
  return buildMultiSigTx(tx);
}

updateInterestModels().then(console.log);