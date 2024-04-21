import { InterestModel } from '../contracts/protocol';
import {
  SupportedBaseAssets,
  coinDecimals,
} from './chain-data';

const scale = 10 ** 12;
const interestRateScale = 10 ** 7;
const midKink = 60 * (scale / 100); // 60%
const highKink = 90 * (scale / 100); // 90%
const revenueFactor = 10 * (scale / 100); // 10%
const borrowWeight = scale; // 1

const getRatePerSec = (ratePerYear: number) => {
  const secsPerYear = 365 * 24 * 60 * 60;
  return Math.floor(ratePerYear * (scale / 100) * interestRateScale / secsPerYear);
}

export const suiInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sui - 2), // 0.01 SUI
};

export const scaInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sca - 1), // 0.1 SCA
}

export const cetusInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.cetus), // 1 CETUS
}

export const wormholeEthInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeEth - 3), // 0.001 ETH
};

export const wormholeUsdcInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(6), // 6%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeUsdc - 2), // 0.01 USDC
}

export const wormholeUsdtInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(6), // 6%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeUsdt - 2), // 0.01 USDT
}

export const afSuiInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.afSui - 2), // 0.01 afSUI
};

export const haSuiInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haSui - 2), // 0.01 haSUI
};

export const vSuiInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 60%
  highKink, // 90%

  revenueFactor, // 10%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haSui - 2), // 0.01 haSUI
};

export const interestModels: Record<SupportedBaseAssets, InterestModel> = {
  sui: suiInterestModel,
  sca: scaInterestModel,
  afSui: afSuiInterestModel,
  haSui: haSuiInterestModel,
  vSui: vSuiInterestModel,
  cetus: cetusInterestModel,
  wormholeEth: wormholeEthInterestModel,
  wormholeUsdc: wormholeUsdcInterestModel,
  wormholeUsdt: wormholeUsdtInterestModel,
}
