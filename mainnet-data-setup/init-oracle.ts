import { SUI_TYPE_ARG } from '@mysten/sui.js';
import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  pythRuleTxBuilder,
  pythRuleStructType,
  pythOracleData,
} from 'contracts/sui_x_oracle/pyth_rule'
import {
  xOracleTxBuilder
} from 'contracts/sui_x_oracle/x_oracle'
import {
  wormholeUsdcType,
} from './chain-data'

export const initXOracle = (tx: SuiTxBlock) => {
  addRulesForXOracle(tx);
  registerPythPriceObject(tx);
}

export const addRulesForXOracle = (tx: SuiTxBlock) => {
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, pythRuleStructType);
}

export const registerPythPriceObject = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: wormholeUsdcType, priceObject: pythOracleData.priceFeeds.usdc_usd.priceFeedObjectId },
    { coinType: SUI_TYPE_ARG, priceObject: pythOracleData.priceFeeds.sui_usd.priceFeedObjectId }
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.priceObject, pair.coinType);
  });
}
