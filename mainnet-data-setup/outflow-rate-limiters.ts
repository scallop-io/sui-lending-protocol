import { OutflowLimiterModel } from '../contracts/protocol'
import {
  coinDecimals,
  SupportedBaseAssets,
} from './chain-data'

const outflowCycleDuration = 60 * 60 * 24 // 1 day
const outflowSegmentDuration = 60 * 30 // 30 minutes

export const outflowRateLimiters: Record<SupportedBaseAssets, OutflowLimiterModel> = {
  sui: {
    outflowLimit: 4 * 10 ** (7 + coinDecimals.sui), // 40 million SUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  afSui: {
    outflowLimit: 5 * 10 ** (6 + coinDecimals.afSui), // 5 million afSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  haSui: {
    outflowLimit: 5 * 10 ** (6 + coinDecimals.haSui), // 5 million haSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  vSui: {
    outflowLimit: 5 * 10 ** (6 + coinDecimals.vSui), // 5 million vSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  sca: {
    outflowLimit: 10 ** (6 + coinDecimals.sca), // 1 million SCA per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  cetus: {
    outflowLimit: 10 ** (6 + coinDecimals.cetus), // 1 million CETUS per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeEth: {
    outflowLimit: 2 * 10 ** (4 + coinDecimals.wormholeEth), // 20,000 ETH per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdc: {
    outflowLimit: 4 * 10 ** (7 + coinDecimals.wormholeUsdc), // 40 million USDC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdt: {
    outflowLimit: 4 * 10 ** (7 + coinDecimals.wormholeUsdt), // 40 million USDT per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
}
