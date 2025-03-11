import * as path from "path";
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";
import { testCoinTypes } from "contracts/test_coin";
import {
  xOracleTxBuilder,
  // switchboardRuleTxBuilder,
  // switchboardOracleData,
  pythRuleTxBuilder,
  pythOracleData,
  // supraRuleTxBuilder,
  switchboardOnDemandRuleTxBuilder,
} from "./index";

import { getVaas } from "./get-vaas";

export const updatePrice = async (tx: SuiTxBlock, coinType: string) => {
  const request = xOracleTxBuilder.priceUpdateRequest(tx, coinType);
  await updatePythPriceForRequest(tx, request, coinType);
  // updateSwitchboardPriceForRequest(tx, request, coinType);
  // updateSupraPriceForRequest(tx, request, coinType);
  await updateSwitchboardOnDemandPriceForRequest(tx, request, coinType, "");
  xOracleTxBuilder.confirmPriceUpdateRequest(tx, request, coinType);
};

export const updatePythPriceForRequest = async (
  tx: SuiTxBlock,
  updateRequest: SuiTxArg,
  coinType: string
) => {
  const priceFeed = getPythPriceFeed(coinType);
  const [vaa] = await getVaas([priceFeed.priceFeedId]);
  pythRuleTxBuilder.setPrice(
    tx,
    updateRequest,
    priceFeed.priceFeedObjectId,
    tx.pure([...Buffer.from(vaa, "base64")]),
    coinType
  );
};

// export const updateSupraPriceForRequest = (
//   tx: SuiTxBlock,
//   updateRequest: SuiTxArg,
//   coinType: string
// ) => {
//   supraRuleTxBuilder.setPrice(tx, updateRequest, coinType);
// };

// export const updateSwitchboardPriceForRequest = (
//   tx: SuiTxBlock,
//   updateRequest: SuiTxArg,
//   coinType: string
// ) => {
//   const aggregator = getSwitchboardAggregator(coinType);
//   switchboardRuleTxBuilder.setPrice(tx, updateRequest, aggregator, coinType);
// };

export const updateSwitchboardOnDemandPriceForRequest = async (
  tx: SuiTxBlock,
  updateRequest: SuiTxArg,
  coinType: string,
  suiRPC: string
) => {
  const aggregator = getSwitchboardOnDemandAggregator(coinType);
  await switchboardOnDemandRuleTxBuilder.updateAggregator(
    tx,
    aggregator,
    suiRPC
  );
  switchboardOnDemandRuleTxBuilder.setPrice(
    tx,
    updateRequest,
    aggregator,
    coinType
  );
};

const getPythPriceFeed = (coinType: string) => {
  if (coinType == testCoinTypes.btc) {
    return pythOracleData.priceFeeds.btc_usd;
  } else if (coinType === testCoinTypes.eth) {
    return pythOracleData.priceFeeds.eth_usd;
  } else if (coinType === testCoinTypes.usdc) {
    return pythOracleData.priceFeeds.usdc_usd;
  } else if (coinType === testCoinTypes.usdt) {
    return pythOracleData.priceFeeds.usdt_usd;
  } else if (coinType === "0x2::sui::SUI") {
    return pythOracleData.priceFeeds.sui_usd;
  } else {
    throw new Error(`Unsupported coin type: ${coinType} for pyth price feed`);
  }
};

// const getSwitchboardAggregator = (coinType: string) => {
//   if (coinType == testCoinTypes.btc) {
//     return switchboardOracleData.btc_usd;
//   } else if (coinType === testCoinTypes.eth) {
//     return switchboardOracleData.eth_usd;
//   } else if (coinType === testCoinTypes.usdc) {
//     return switchboardOracleData.usdc_usd;
//   } else if (coinType === testCoinTypes.usdt) {
//     return switchboardOracleData.usdt_usd;
//   } else if (coinType === "0x2::sui::SUI") {
//     return switchboardOracleData.sui_usd;
//   } else {
//     throw new Error(
//       `Unsupported coin type: ${coinType} for switchboard aggregator`
//     );
//   }
// };

// TODO Implement this function with custom Switchboard Aggregator types for On-Demand
const getSwitchboardOnDemandAggregator = (coinType: string) => {
  throw new Error("Not implemented");
};
