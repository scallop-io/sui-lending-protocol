import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import { riskModels } from './risk-models';
import { oracles } from './asset-oracles';
import { coinTypes, coinMetadataIds } from './chain-data';
import {
  protocolTxBuilder,
  RiskModel,
} from '../contracts/protocol';
import { pythRuleTxBuilder } from '../contracts/sui_x_oracle';
import {
  decimalsRegistryTxBuilder,
} from '../contracts/libs/coin_decimals_registry';
import { MULTI_SIG_ADDRESS } from './multi-sig';
import {toB64} from "@mysten/sui.js";

const integrateLSD = (txBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.afSui, riskModel: riskModels.afSui },
    { type: coinTypes.haSui, riskModel: riskModels.haSui },
  ];
  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: coinTypes.afSui, metadataId: coinMetadataIds.afSui },
    { type: coinTypes.haSui, metadataId: coinMetadataIds.haSui },
  ];
  const oraclePairs: { type: string, pythPriceObject: string  }[] = [
    { type: coinTypes.afSui, pythPriceObject: oracles.afSui.pythPriceObjectId },
    { type: coinTypes.haSui, pythPriceObject: oracles.haSui.pythPriceObjectId },
  ];

  // register decimals
  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(txBlock, pair.metadataId, pair.type);
  });
  // add risk models
  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(txBlock, pair.riskModel, pair.type);
  });
  // register pyth price objects
  oraclePairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.pythPriceObject, pair.type);
  });
}

const tx = new SuiTxBlock();
integrateLSD(tx);
tx.setSender(MULTI_SIG_ADDRESS);
tx.build({ provider: suiKit.provider() }).then(bytes => toB64(bytes)).then(console.log).catch(console.error).finally(() => process.exit(0));
