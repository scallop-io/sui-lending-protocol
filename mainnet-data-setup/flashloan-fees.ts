import {
  SupportedBaseAssets,
} from './chain-data';


// Fee is 10000 based, 10 means 0.1%
export const FlashloanFees: Record<SupportedBaseAssets, number> = {
  sui: 10,
  wormholeUsdc: 10,
  wormholeUsdt: 10,
  sca: 10,
  afSui: 10,
  haSui: 10,
  vSui: 10,
  cetus: 10,
  wormholeEth: 10,
  wormholeBtc: 10,
  sbwBTC: 10,
  wormholeSol: 10,
  nativeUsdc: 10,
  sbEth: 10,
  deep: 10,
  fud: 10,
  fdusd: 10,
  sbUsdt: 10,
  blub: 10,
  mUsd: 10,
  ns: 10,
  usdy: 10,
  wal: 10,
}
