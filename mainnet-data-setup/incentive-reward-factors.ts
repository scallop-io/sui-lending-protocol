import { SupportedBaseAssets } from './chain-data';
import { IncentiveRewardFactor } from '../contracts/protocol';
export const incentiveRewardFactors: Record<SupportedBaseAssets, IncentiveRewardFactor> = {
  sui: { rewardFactor: 2, scale: 1 },
  wormholeEth: { rewardFactor: 1, scale: 1 },
  wormholeUsdc: { rewardFactor: 1, scale: 1 },
  wormholeUsdt: { rewardFactor: 1, scale: 1 },
};
