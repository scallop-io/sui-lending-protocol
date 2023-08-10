import { OutflowLimiterModel } from '../contracts/protocol'
import {
  coinDecimals,
  SupportedBaseAssets,
} from './chain-data'

const outflowCycleDuration = 60 * 60 * 24 // 1 day
const outflowSegmentDuration = 60 * 30 // 30 minutes

export const outflowRateLimiters: Record<SupportedBaseAssets, OutflowLimiterModel> = {
  sui: {
    outflowLimit: 10 ** (6 + coinDecimals.sui), // 1 million SUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  cetus: {
    outflowLimit: 10 ** (6 + coinDecimals.cetus), // 1 million CETUS per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeEth: {
    outflowLimit: 10 ** (3 + coinDecimals.wormholeEth), // 1000 ETH per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeBtc: {
    outflowLimit: 10 ** (2 + coinDecimals.wormholeBtc), // 100 BTC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeSol: {
    outflowLimit: 10 ** (4 + coinDecimals.wormholeSol), // 10,000 SOL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeApt: {
    outflowLimit: 10 ** (5 + coinDecimals.wormholeApt), // 100,000 APT per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdc: {
    outflowLimit: 10 ** (6 + coinDecimals.wormholeUsdc), // 1 million USDC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdt: {
    outflowLimit: 10 ** (6 + coinDecimals.wormholeUsdt), // 1 million USDT per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
}
