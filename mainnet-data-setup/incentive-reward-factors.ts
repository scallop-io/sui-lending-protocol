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
  wormholeSol: calculateRewardFactor(150, coinDecimals.wormholeSol),
  nativeUsdc: calculateRewardFactor(1, coinDecimals.nativeUsdc),
  sbEth: calculateRewardFactor(2000, coinDecimals.sbEth),
  deep: calculateRewardFactor(0, coinDecimals.deep),
  fud: calculateRewardFactor(0, coinDecimals.fud),
};
