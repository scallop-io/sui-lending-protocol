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
    outflowLimit: 5 * 10 ** (5 + coinDecimals.haSui), // 500K haSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  vSui: {
    outflowLimit: 5 * 10 ** (5 + coinDecimals.vSui), // 500K vSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  sca: {
    outflowLimit: 2 * 10 ** (5 + coinDecimals.sca), // 200k SCA per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  cetus: {
    outflowLimit: 10 ** (6 + coinDecimals.cetus), // 1 million CETUS per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeEth: {
    outflowLimit: 5 * 10 ** (2 + coinDecimals.wormholeEth), // 500 ETH per day
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
  wormholeBtc: {
    outflowLimit: 2 * 10 ** (0 + coinDecimals.wormholeBtc), // 2 BTC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeSol: {
    outflowLimit: 1 * 10 ** (3 + coinDecimals.wormholeSol), // 1000 SOL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  nativeUsdc: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.nativeUsdc), // 3 million USDC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  sbEth: {
    outflowLimit: 25 * 10 ** (1 + coinDecimals.sbEth), // 250 ETH per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  deep: {
    outflowLimit: 5 * 10 ** (6 + coinDecimals.deep), // 5M DEEP per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  fud: {
    outflowLimit: 1 * 10 ** (12 + coinDecimals.fud), // 1T FUD per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
}
