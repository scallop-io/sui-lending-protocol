import { InterestModel } from '../contracts/protocol';
import {
  SupportedBaseAssets,
  coinDecimals,
} from './chain-data';

const scale = 10 ** 12;
const interestRateScale = 10 ** 7;
const midKink = 70 * (scale / 100); // 70%
const highKink = 90 * (scale / 100); // 90%
const revenueFactor = 20 * (scale / 100); // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
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

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haSui - 2), // 0.01 vSUI
};

export const wormholeSolInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeSol - 3), // 0.001 Sol
};

export const wormholeBtcInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeBtc - 6), // 0.000001 Btc
};

export const nativeUsdcInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(6), // 6%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 70%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.nativeUsdc - 2), // 0.01 USDC
}

export const sbEthInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(8), // 8%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 70%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sbEth - 3), // 0.001 ETH
};

export const deepInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(40), // 40%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 70%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.deep + 1), // 10 DEEP
};

export const fudInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(40), // 40%
  borrowRateOnHighKink: getRatePerSec(100), // 100%
  maxBorrowRate: getRatePerSec(300), // 300%

  midKink, // 70%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight: (scale * 2), // 2
  scale,
  minBorrowAmount: 10 ** (coinDecimals.fud + 7), // 10M FUD
};

export const fdusdInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(6), // 6%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 70%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.fdusd - 2), // 0.01 FDUSD
}

export const sbUsdtInterestModel: InterestModel = {
  baseBorrowRatePerSec: 0,
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(6), // 6%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 70%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeUsdt - 2), // 0.01 USDT
}

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
  wormholeBtc: wormholeBtcInterestModel,
  wormholeSol: wormholeSolInterestModel,
  nativeUsdc: nativeUsdcInterestModel,
  sbEth: sbEthInterestModel,
  deep: deepInterestModel,
  fud: fudInterestModel,
  fdusd: fdusdInterestModel,
  sbUsdt: sbUsdtInterestModel,
}
