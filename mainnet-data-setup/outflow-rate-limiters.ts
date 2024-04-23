import { OutflowLimiterModel } from '../contracts/protocol'
import {
  coinDecimals,
  SupportedBaseAssets,
} from './chain-data'

const outflowCycleDuration = 60 * 60 * 24 // 1 day
const outflowSegmentDuration = 60 * 30 // 30 minutes

export const outflowRateLimiters: Record<SupportedBaseAssets, OutflowLimiterModel> = {
  sui: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.sui), // 3 million SUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  afSui: {
    outflowLimit: 10 ** (6 + coinDecimals.afSui), // 1 million afSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  haSui: {
    outflowLimit: 10 ** (6 + coinDecimals.haSui), // 1 million haSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  vSui: {
    outflowLimit: 10 ** (4 + coinDecimals.vSui), // 10k vSUI per day
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
    outflowLimit: 5 * 10 ** (3 + coinDecimals.wormholeEth), // 5000 ETH per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdc: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.wormholeUsdc), // 3 million USDC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdt: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.wormholeUsdt), // 3 million USDT per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
}
