import { SupportedBaseAssets, coinDecimals } from './chain-data';
import { IncentiveRewardFactor } from '../contracts/protocol';


/**
 * Reward factors is calculated based on the usd price of the asset.
 * The formula is:
 * rewardFactor = usdPrice * math.pow(10, benchmarkDecimal - coinDecimals) * boost
 *
 * boost is used to adjust the reward factor to favor some assets.
 */
const calculateRewardFactor = (usdPrice: number, coinDecimals: number, boost: number = 1): IncentiveRewardFactor => {
  // we use 9 as the benchmark decimal
  const benchmarkDecimal = 9;

  let factorValue = usdPrice * Math.pow(10, benchmarkDecimal - coinDecimals) * boost;
  let scale = 1;
  while (factorValue < 1) {
    factorValue *= 10;
    scale *= 10;
  }
  return { rewardFactor: Math.floor(factorValue), scale };
}

export const incentiveRewardFactors: Record<SupportedBaseAssets, IncentiveRewardFactor> = {
  sui: calculateRewardFactor(1, coinDecimals.sui, 2),
  sca: calculateRewardFactor(1, coinDecimals.sca, 2),
  afSui: calculateRewardFactor(1, coinDecimals.afSui, 2),
  haSui: calculateRewardFactor(1, coinDecimals.haSui, 2),
  vSui: calculateRewardFactor(1, coinDecimals.vSui, 2),
  cetus: calculateRewardFactor(0.04, coinDecimals.cetus),
  wormholeEth: calculateRewardFactor(2000, coinDecimals.wormholeEth),
  wormholeUsdc: calculateRewardFactor(1, coinDecimals.wormholeUsdc),
  wormholeUsdt: calculateRewardFactor(1, coinDecimals.wormholeUsdt),
  wormholeBtc: calculateRewardFactor(50000, coinDecimals.wormholeBtc),
  sbwBTC: calculateRewardFactor(50000, coinDecimals.sbwBTC),
  wormholeSol: calculateRewardFactor(150, coinDecimals.wormholeSol),
  nativeUsdc: calculateRewardFactor(1, coinDecimals.nativeUsdc),
  sbEth: calculateRewardFactor(2000, coinDecimals.sbEth),
  deep: calculateRewardFactor(0.1, coinDecimals.deep),
  fud: calculateRewardFactor(1e-7, coinDecimals.fud),
  fdusd: calculateRewardFactor(1, coinDecimals.fdusd),
  sbUsdt: calculateRewardFactor(1, coinDecimals.sbUsdt),
  blub: calculateRewardFactor(1e-8, coinDecimals.blub),
  mUsd: calculateRewardFactor(1, coinDecimals.mUsd),
  ns: calculateRewardFactor(0.2, coinDecimals.ns),
  usdy: calculateRewardFactor(1, coinDecimals.usdy),
};
