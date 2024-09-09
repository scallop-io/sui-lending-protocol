import {
  SupportedBaseAssets,
} from './chain-data';


// Fee is 10000 based, 6 means 0.06%
export const FlashloanFees: Record<SupportedBaseAssets, number> = {
  sui: 6,
  wormholeUsdc: 6,
  wormholeUsdt: 6,
  sca: 6,
  afSui: 6,
  haSui: 6,
  vSui: 6,
  cetus: 6,
  wormholeEth: 6,
  wormholeBtc: 6,
  wormholeSol: 6,
}
