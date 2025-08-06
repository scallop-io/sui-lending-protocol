import {
  SupportedBaseAssets,
  coinDecimals,
} from './chain-data';


export const SupplyLimits: Record<SupportedBaseAssets, number> = {
  sui: 1e8 * Math.pow(10, coinDecimals.sui),
  wormholeUsdc: 0 * Math.pow(10, coinDecimals.wormholeUsdc),
  wormholeUsdt: 0 * Math.pow(10, coinDecimals.wormholeUsdt),
  sca: 15e6 * Math.pow(10, coinDecimals.sca),
  afSui: 1e6 * Math.pow(10, coinDecimals.afSui),
  haSui: 10e6 * Math.pow(10, coinDecimals.haSui), // 10M
  vSui: 0 * Math.pow(10, coinDecimals.vSui), // 0
  cetus: 10e6 * Math.pow(10, coinDecimals.cetus),
  wormholeEth: 0 * Math.pow(10, coinDecimals.wormholeEth),
  wormholeBtc: 0 * Math.pow(10, coinDecimals.wormholeBtc),
  sbwBTC: 20 * Math.pow(10, coinDecimals.sbwBTC),
  wormholeSol: 2e4 * Math.pow(10, coinDecimals.wormholeSol),
  nativeUsdc: 7e7 * Math.pow(10, coinDecimals.nativeUsdc),
  sbEth: 5e3 * Math.pow(10, coinDecimals.sbEth),
  deep: 200e6 * Math.pow(10, coinDecimals.deep), // 200M
  fud: 25e11 * Math.pow(10, coinDecimals.fud),
  fdusd: 20e6 * Math.pow(10, coinDecimals.fdusd),
  sbUsdt: 1e7 * Math.pow(10, coinDecimals.sbUsdt), // 10M
  blub: 25e12 * Math.pow(10, coinDecimals.blub), // 25T
  mUsd: 2e6 * Math.pow(10, coinDecimals.mUsd), // 2M
  ns: 5e6 * Math.pow(10, coinDecimals.ns), // 5M
  usdy: 5e6 * Math.pow(10, coinDecimals.usdy), // 5M
  wal: 25_000_000 * Math.pow(10, coinDecimals.wal), // 25M
  haedal: 20_000_000 * Math.pow(10, coinDecimals.haedal), // 20M
  wWal: 10_000_000 * Math.pow(10, coinDecimals.wWal), // 10M
  haWal: 10_000_000 * Math.pow(10, coinDecimals.haWal), // 10M
}
