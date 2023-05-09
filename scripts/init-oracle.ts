import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  xOracleTxBuilder,
  pythRuleTxBuilder,
  pythRuleType,
  pythTestnetIds,
  switchboardRuleTxBuilder,
  switchboardRuleType,
  switchboardTestnetIds
} from '../sui_x_oracle'
import {
  testCoinTypes
} from '../test_coin'

export const initXOracleForTest = (tx: SuiTxBlock) => {
  addRulesForXOracle(tx);
  registerSwitchboardAggregators(tx);
  registerPythPriceFeedObjects(tx);
}

export const addRulesForXOracle = (tx: SuiTxBlock) => {
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, pythRuleType);
  xOracleTxBuilder.addSecondaryPriceUpdateRule(tx, switchboardRuleType);
}

export const registerSwitchboardAggregators = (tx: SuiTxBlock) => {
  const pairs = [
    { coinType: testCoinTypes.eth, aggregator: switchboardTestnetIds.aggregators.eth_usd },
    { coinType: testCoinTypes.btc, aggregator: switchboardTestnetIds.aggregators.btc_usd },
    { coinType: testCoinTypes.usdc, aggregator: switchboardTestnetIds.aggregators.usdc_usd },
    { coinType: testCoinTypes.usdt, aggregator: switchboardTestnetIds.aggregators.usdt_usd },
    { coinType: '0x2::sui::SUI', aggregator: switchboardTestnetIds.aggregators.sui_usd }
  ];
  pairs.forEach(pair => {
    switchboardRuleTxBuilder.registerSwitchboardAggregator(tx, pair.aggregator, pair.coinType);
  });
}

export const registerPythPriceFeedObjects = (tx: SuiTxBlock) => {
  const pairs = [
    { coinType: testCoinTypes.eth, pythPriceFeedObject: pythTestnetIds.priceFeeds.eth_usd.priceFeedObjectId },
    { coinType: testCoinTypes.btc, pythPriceFeedObject: pythTestnetIds.priceFeeds.btc_usd.priceFeedObjectId },
    { coinType: testCoinTypes.usdc, pythPriceFeedObject: pythTestnetIds.priceFeeds.usdc_usd.priceFeedObjectId },
    { coinType: testCoinTypes.usdt, pythPriceFeedObject: pythTestnetIds.priceFeeds.usdt_usd.priceFeedObjectId },
    { coinType: '0x2::sui::SUI', pythPriceFeedObject: pythTestnetIds.priceFeeds.sui_usd.priceFeedObjectId },
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.pythPriceFeedObject, pair.coinType);
  });
}
