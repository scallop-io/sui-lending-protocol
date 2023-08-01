import { OutflowLimiterModel } from '../contracts/protocol'
import {
  suiDecimal,
  wormholeUsdcDecimal,
  wormholeUsdtDecimal,
  wormholeEthDecimal,
} from './chain-data'
export const outflowRateLimiters: Record<string, OutflowLimiterModel> = {
  sui: {
    outflowLimit: 10 ** (6 + suiDecimal), // 1 million SUI per day
    outflowCycleDuration: 60 * 60 * 24, // 1 day
    outflowSegmentDuration: 60 * 30, // 30 minutes
  },
  wormholeEth: {
    outflowLimit: 10 ** (3 + wormholeEthDecimal), // 1000 ETH per day
    outflowCycleDuration: 60 * 60 * 24, // 1 day
    outflowSegmentDuration: 60 * 30, // 30 minutes
  },
  wormholeUsdc: {
    outflowLimit: 10 ** (6 + wormholeUsdcDecimal), // 1 million USDC per day
    outflowCycleDuration: 60 * 60 * 24, // 1 day
    outflowSegmentDuration: 60 * 30, // 30 minutes
  },
  wormholeUsdt: {
    outflowLimit: 10 ** (6 + wormholeUsdtDecimal), // 1 million USDT per day
    outflowCycleDuration: 60 * 60 * 24, // 1 day
    outflowSegmentDuration: 60 * 30, // 30 minutes
  },
}
