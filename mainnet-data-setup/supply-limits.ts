import {
  SupportedBaseAssets,
  coinDecimals,
} from './chain-data';


export const SupplyLimits: Record<SupportedBaseAssets, number> = {
  sui: 1e9 * Math.pow(10, coinDecimals.sui),
  wormholeUsdc: 1e9 * Math.pow(10, coinDecimals.wormholeUsdc),
  wormholeUsdt: 1e9 * Math.pow(10, coinDecimals.wormholeUsdt),
  sca: 1e8 * Math.pow(10, coinDecimals.sca),
  afSui: 1e8 * Math.pow(10, coinDecimals.afSui),
  haSui: 1e8 * Math.pow(10, coinDecimals.haSui),
  vSui: 1e7 * Math.pow(10, coinDecimals.vSui),
  cetus: 2e6 * Math.pow(10, coinDecimals.cetus),
  wormholeEth: 1e5 * Math.pow(10, coinDecimals.wormholeEth),
}
