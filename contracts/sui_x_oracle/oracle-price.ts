import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit"
import { testCoinTypes } from "contracts/test_coin"
import {
  xOracleTxBuilder,
  pythRuleTxBuilder,
  pythTestnetIds,
  switchboardRuleTxBuilder,
  switchboardTestnetIds,
} from "./index"
import { getVaas } from "./get-vaas"

export const updatePythPriceForRequest = async (tx: SuiTxBlock, updateRequest: SuiTxArg, coinType: string) => {
  const priceFeed = getPythPriceFeed(coinType);
  const [vaa] = await getVaas([priceFeed.priceFeedId]);
  pythRuleTxBuilder.setPrice(
    tx,
    updateRequest,
    priceFeed.priceFeedObjectId,
    tx.pure([...Buffer.from(vaa, "base64")]),
    coinType
  );
}

export const updateSwitchboardPriceForRequest = (tx: SuiTxBlock, updateRequest: SuiTxArg, coinType: string) => {
  const aggregator = getSwitchboardAggregator(coinType);
  switchboardRuleTxBuilder.setPrice(
    tx,
    updateRequest,
    aggregator,
    coinType
  );
}

export const updatePrice = async (tx: SuiTxBlock, coinType: string) => {
  const request = xOracleTxBuilder.priceUpdateRequest(tx, coinType);
  await updatePythPriceForRequest(tx, request, coinType);
  updateSwitchboardPriceForRequest(tx, request, coinType);
  xOracleTxBuilder.confirmPriceUpdateRequest(tx, request, coinType);
}

const getPythPriceFeed = (coinType: string) => {
  if (coinType == testCoinTypes.btc) {
    return pythTestnetIds.priceFeeds.btc_usd;
  } else if (coinType === testCoinTypes.eth) {
    return pythTestnetIds.priceFeeds.eth_usd;
  } else if (coinType === testCoinTypes.usdc) {
    return pythTestnetIds.priceFeeds.usdc_usd;
  } else if (coinType === testCoinTypes.usdt) {
    return pythTestnetIds.priceFeeds.usdt_usd;
  } else if (coinType === '0x2::sui::SUI') {
    return pythTestnetIds.priceFeeds.sui_usd;
  } else {
    throw new Error(`Unsupported coin type: ${coinType} for pyth price feed`);
  }
}

const getSwitchboardAggregator = (coinType: string) => {
  if (coinType == testCoinTypes.btc) {
    return switchboardTestnetIds.aggregators.btc_usd;
  } else if (coinType === testCoinTypes.eth) {
    return switchboardTestnetIds.aggregators.eth_usd;
  } else if (coinType === testCoinTypes.usdc) {
    return switchboardTestnetIds.aggregators.usdc_usd;
  } else if (coinType === testCoinTypes.usdt) {
    return switchboardTestnetIds.aggregators.usdt_usd;
  } else if (coinType === '0x2::sui::SUI') {
    return switchboardTestnetIds.aggregators.sui_usd;
  } else {
    throw new Error(`Unsupported coin type: ${coinType} for switchboard aggregator`);
  }
}
