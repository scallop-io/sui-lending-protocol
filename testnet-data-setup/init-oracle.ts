import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  xOracleTxBuilder,
  switchboardRuleTxBuilder,
  switchboardRuleStructType,
  switchboardOracleData,
  pythRuleTxBuilder,
  pythRuleStructType,
  pythOracleData,
  supraRuleTxBuilder,
  supraRuleStructType,
  supraOracleData
} from 'contracts/sui_x_oracle'
import {
  testCoinTypes
} from 'contracts/test_coin'

export const initXOracleForTest = (tx: SuiTxBlock) => {
  addRulesForXOracle(tx);
  registerSwitchboardAggregators(tx);
  registerSupraPriceIds(tx);
  registerPythPriceObject(tx);
}

export const addRulesForXOracle = (tx: SuiTxBlock) => {
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, pythRuleStructType);
  // xOracleTxBuilder.addSecondaryPriceUpdateRule(tx, switchboardRuleStructType);
  // xOracleTxBuilder.addSecondaryPriceUpdateRule(tx, supraRuleStructType);
}

export const registerSwitchboardAggregators = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: testCoinTypes.eth, aggregator: switchboardOracleData.eth_usd },
    { coinType: testCoinTypes.btc, aggregator: switchboardOracleData.btc_usd },
    { coinType: testCoinTypes.usdc, aggregator: switchboardOracleData.usdc_usd },
    { coinType: testCoinTypes.usdt, aggregator: switchboardOracleData.usdt_usd },
    { coinType: '0x2::sui::SUI', aggregator: switchboardOracleData.sui_usd }
  ];
  pairs.forEach(pair => {
    switchboardRuleTxBuilder.registerSwitchboardAggregator(tx, pair.aggregator, pair.coinType);
  });
}

export const registerSupraPriceIds = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: testCoinTypes.eth, priceId: supraOracleData.priceIds.eth_usd },
    { coinType: testCoinTypes.btc, priceId: supraOracleData.priceIds.btc_usd },
    { coinType: testCoinTypes.usdc, priceId: supraOracleData.priceIds.usdc_usd },
    { coinType: testCoinTypes.usdt, priceId: supraOracleData.priceIds.usdt_usd },
    { coinType: '0x2::sui::SUI', priceId: supraOracleData.priceIds.sui_usd }
  ];
  pairs.forEach(pair => {
    supraRuleTxBuilder.registerSupraPairId(tx, pair.priceId, pair.coinType);
  });
}

export const registerPythPriceObject = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: testCoinTypes.eth, priceObject: pythOracleData.priceFeeds.eth_usd.priceFeedObjectId },
    { coinType: testCoinTypes.btc, priceObject: pythOracleData.priceFeeds.btc_usd.priceFeedObjectId },
    { coinType: testCoinTypes.usdc, priceObject: pythOracleData.priceFeeds.usdc_usd.priceFeedObjectId },
    { coinType: testCoinTypes.usdt, priceObject: pythOracleData.priceFeeds.usdt_usd.priceFeedObjectId },
    { coinType: '0x2::sui::SUI', priceObject: pythOracleData.priceFeeds.sui_usd.priceFeedObjectId }
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.priceObject, pair.coinType);
  });
}
