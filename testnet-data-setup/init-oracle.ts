import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  xOracleTxBuilder,
  switchboardRuleTxBuilder,
  switchboardRuleStructType,
} from '../contracts/sui_x_oracle'
import { switchboardTestTxBuilder, testAggregatorIds } from "../contracts/sui_x_oracle/test"
import {
  testCoinTypes
} from '../contracts/test_coin'

export const initXOracleForTest = (tx: SuiTxBlock) => {
  addRulesForXOracle(tx);
  registerSwitchboardAggregators(tx);
  setAggregatorPrice(tx);
}

export const addRulesForXOracle = (tx: SuiTxBlock) => {
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, switchboardRuleStructType);
}

export const registerSwitchboardAggregators = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: testCoinTypes.eth, aggregator: testAggregatorIds.eth_usd },
    { coinType: testCoinTypes.btc, aggregator: testAggregatorIds.btc_usd },
    { coinType: testCoinTypes.usdc, aggregator: testAggregatorIds.usdc_usd },
    { coinType: testCoinTypes.usdt, aggregator: testAggregatorIds.usdt_usd },
    { coinType: '0x2::sui::SUI', aggregator: testAggregatorIds.sui_usd }
  ];
  pairs.forEach(pair => {
    switchboardRuleTxBuilder.registerSwitchboardAggregator(tx, pair.aggregator, pair.coinType);
  });
}

export const setAggregatorPrice = (tx: SuiTxBlock) => {
  const pairs = [
    { price: { value: 1800 * 10 ** 8, scale: 8 }, aggregator: testAggregatorIds.eth_usd },
    { price: { value: 26000 * 10 ** 8, scale: 8 }, aggregator: testAggregatorIds.btc_usd },
    { price: { value: 10 ** 8, scale: 8 }, aggregator: testAggregatorIds.usdc_usd },
    { price: { value: 10 ** 8, scale: 8 }, aggregator: testAggregatorIds.usdt_usd },
    { price: { value: 10 ** 8, scale: 8 }, aggregator: testAggregatorIds.sui_usd }
  ];
  pairs.forEach(pair => {
    switchboardTestTxBuilder.setValue(tx, pair.aggregator, pair.price.value, pair.price.scale);
  });
}
