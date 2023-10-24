import {
  pythOracleData,
} from 'contracts/sui_x_oracle/pyth_rule';
import {
  SupportedCollaterals,
  SupportedBaseAssets
} from './chain-data';

type OracleData = {
  pythPriceObjectId: string;
}
export const oracles: Record<SupportedBaseAssets | SupportedCollaterals, OracleData> = {
  sui: { pythPriceObjectId: pythOracleData.priceFeeds.sui_usd.priceFeedObjectId },
  cetus: { pythPriceObjectId: pythOracleData.priceFeeds.cetus_usd.priceFeedObjectId },
  afSui: { pythPriceObjectId: pythOracleData.priceFeeds.sui_usd.priceFeedObjectId },
  haSui: { pythPriceObjectId: pythOracleData.priceFeeds.sui_usd.priceFeedObjectId },
  wormholeUsdc: { pythPriceObjectId: pythOracleData.priceFeeds.usdc_usd.priceFeedObjectId },
  wormholeUsdt: { pythPriceObjectId: pythOracleData.priceFeeds.usdt_usd.priceFeedObjectId },
  wormholeEth: { pythPriceObjectId: pythOracleData.priceFeeds.eth_usd.priceFeedObjectId },
};
