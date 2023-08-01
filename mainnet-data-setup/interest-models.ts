import { InterestModel } from '../contracts/protocol';
import {
  suiDecimal,
  wormholeEthDecimal,
  wormholeUsdcDecimal,
  wormholeUsdtDecimal,
} from './chain-data';

const scale = 10 ** 12;
const interestRateScale = 10 ** 7;
let secsPerYear = 365 * 24 * 60 * 60;
export const suiInterestModel: InterestModel = {
  // baseBorrowRatePerSec: 15854986000, // 5 * (10 ** 12) / (365 * 24 * 3600) / 100 * (10 ** 7)
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: Math.floor(10 * (scale / 100) * interestRateScale / secsPerYear), // 10%
  borrowRateOnHighKink: Math.floor(100 * (scale / 100) * interestRateScale / secsPerYear), // 100%
  maxBorrowRate: Math.floor(300 * (scale / 100) * interestRateScale / secsPerYear), // 300%

  midKink: 60 * (scale / 100), // 60%
  highKink: 90 * (scale / 100), // 90%

  revenueFactor: 5 * (scale / 100), // 5%
  borrowWeight: scale, // 1
  scale,
  minBorrowAmount: 10 ** (suiDecimal - 2), // 0.01 SUI
};

export const wormholeEthInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: Math.floor(10 * (scale / 100) * interestRateScale / secsPerYear), // 10%
  borrowRateOnHighKink: Math.floor(100 * (scale / 100) * interestRateScale / secsPerYear), // 100%
  maxBorrowRate: Math.floor(300 * (scale / 100) * interestRateScale / secsPerYear), // 300%

  midKink: 60 * (scale / 100), // 60%
  highKink: 90 * (scale / 100), // 90%

  revenueFactor: 5 * (scale / 100), // 5%
  borrowWeight: scale, // 1
  scale,
  // TODO: check the eth decimal, and change the minBorrowAmount
  minBorrowAmount: 10 ** (wormholeEthDecimal - 2), // 0.01 ETH
};

export const wormholeUsdcInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: Math.floor(8 * (scale / 100) * interestRateScale / secsPerYear), // 8%
  borrowRateOnHighKink: Math.floor(50 * (scale / 100) * interestRateScale / secsPerYear), // 50%
  maxBorrowRate: Math.floor(150 * (scale / 100) * interestRateScale / secsPerYear), // 150%

  midKink: 60 * (scale / 100), // 60%
  highKink: 90 * (scale / 100), // 90%

  revenueFactor: 5 * (scale / 100), // 5%
  borrowWeight: scale, // 1
  scale,
  minBorrowAmount: 10 ** (wormholeUsdcDecimal - 2), // 0.01 USDC
}

export const wormholeUsdtInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: Math.floor(8 * (scale / 100) * interestRateScale / secsPerYear), // 8%
  borrowRateOnHighKink: Math.floor(50 * (scale / 100) * interestRateScale / secsPerYear), // 50%
  maxBorrowRate: Math.floor(150 * (scale / 100) * interestRateScale / secsPerYear), // 150%

  midKink: 60 * (scale / 100), // 60%
  highKink: 90 * (scale / 100), // 90%

  revenueFactor: 5 * (scale / 100), // 5%
  borrowWeight: scale, // 1
  scale,
  minBorrowAmount: 10 ** (wormholeUsdtDecimal - 2), // 0.01 USDT
}

export const interestModels = {
  sui: suiInterestModel,
  wormholeEth: wormholeEthInterestModel,
  wormholeUsdc: wormholeUsdcInterestModel,
  wormholeUsdt: wormholeUsdtInterestModel,
}
