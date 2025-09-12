import { OutflowLimiterModel } from '../contracts/protocol'
import {
  coinDecimals,
  SupportedBaseAssets,
} from './chain-data'

const outflowCycleDuration = 60 * 60 * 24 // 1 day
const outflowSegmentDuration = 60 * 30 // 30 minutes

export const outflowRateLimiters: Record<SupportedBaseAssets, OutflowLimiterModel> = {
  sui: {
    outflowLimit: 1 * 10 ** (6 + coinDecimals.sui), // 1 million SUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  afSui: {
    outflowLimit: 5_000 * 10 ** (coinDecimals.afSui), // 5k afSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  haSui: {
    outflowLimit: 5_000 * 10 ** (coinDecimals.haSui), // 5k haSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  vSui: {
    outflowLimit: 10 ** (4 + coinDecimals.vSui), // 10k vSUI per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  sca: {
    outflowLimit: 2 * 10 ** (5 + coinDecimals.sca), // 200k SCA per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  cetus: {
    outflowLimit: 5 * 10 ** (5 + coinDecimals.cetus), // 500k CETUS per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeEth: {
    outflowLimit: 25 * 10 ** coinDecimals.wormholeEth, // 25 ETH per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeUsdc: {
    outflowLimit: 5 * 10 ** (5 + coinDecimals.wormholeUsdc), // 500k USDC per day
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
  sbwBTC: {
    outflowLimit: 1 * 10 ** (0 + coinDecimals.sbwBTC), // 1 BTC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wormholeSol: {
    outflowLimit: 1 * 10 ** (2 + coinDecimals.wormholeSol), // 100 SOL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  nativeUsdc: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.nativeUsdc), // 3 million USDC per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  sbEth: {
    outflowLimit: 50 * 10 ** (coinDecimals.sbEth), // 50 ETH per day
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
  fdusd: {
    outflowLimit: 5 * 10 ** (5 + coinDecimals.fdusd), // 500k FDUSD per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  mUsd: {
    outflowLimit: 5 * 10 ** (4 + coinDecimals.mUsd), // 50k MUSD per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },  
  sbUsdt: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.sbUsdt), // 3 million USDT per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  usdy: {
    outflowLimit: 10 ** (6 + coinDecimals.usdy), // 1 million USDY per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  blub: {
    outflowLimit: 2 * 10 ** (12 + coinDecimals.blub), // 2T BLUB per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  ns: {
    outflowLimit: 1 * 10 ** (5 + coinDecimals.ns), // 100k NS per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wal: {
    outflowLimit: 3 * 10 ** (6 + coinDecimals.wal), // 3M WAL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  haedal: {
    outflowLimit: 5 * 10 ** (5 + coinDecimals.haedal), // 500k HAEDAL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  wWal: {
    outflowLimit: 10_000 * 10 ** (coinDecimals.wWal), // 10k wWAL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },
  haWal: {
    outflowLimit: 10_000 * 10 ** (coinDecimals.haWal), // 10k haWAL per day
    outflowCycleDuration,
    outflowSegmentDuration,
  },

}
