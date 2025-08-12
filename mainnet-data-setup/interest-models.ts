import { InterestModel } from '../contracts/protocol';
import {
  SupportedBaseAssets,
  coinDecimals,
} from './chain-data';

const scale = 10 ** 12;
const interestRateScale = 10 ** 7;
const midKink = 80 * (scale / 100); // 80%
const highKink = 90 * (scale / 100); // 90%
const revenueFactor = 20 * (scale / 100); // 20%
const borrowWeight = scale; // 1

const getRatePerSec = (ratePerYear: number) => {
  const secsPerYear = 365 * 24 * 60 * 60;
  return Math.floor(ratePerYear * (scale / 100) * interestRateScale / secsPerYear);
}

export const suiInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sui - 2), // 0.01 SUI
};

export const scaInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20), // 20%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sca - 1), // 0.1 SCA
}

export const cetusInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20), // 20%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.cetus), // 1 CETUS
}

export const wormholeEthInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeEth - 3), // 0.001 ETH
};

export const wormholeUsdcInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeUsdc - 2), // 0.01 USDC
}

export const wormholeUsdtInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 20 * (scale / 100), // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeUsdt - 2), // 0.01 USDT
}

export const afSuiInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.afSui - 2), // 0.01 afSUI
};

export const haSuiInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haSui - 2), // 0.01 haSUI
};

export const vSuiInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haSui - 2), // 0.01 vSUI
};

export const wormholeSolInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeSol - 3), // 0.001 Sol
};

export const wormholeBtcInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wormholeBtc - 6), // 0.000001 Btc
};

export const sbwBtcInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sbwBTC - 6), // 0.000001 Btc
};

export const nativeUsdcInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink: 85 * (scale / 100), // 85%
  highKink: 95 * (scale / 100), // 95%

  revenueFactor: 20 * (scale / 100), // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.nativeUsdc - 2), // 0.01 USDC
}

export const sbEthInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(5), // 5%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(30), // 30%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor, // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sbEth - 3), // 0.001 ETH
};

export const deepInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.deep + 1), // 10 DEEP
};

export const fudInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight: (scale * 1.25), // 125%
  scale,
  minBorrowAmount: 10 ** (coinDecimals.fud + 7), // 10M FUD
};

export const fdusdInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink: 85 * (scale / 100), // 85%
  highKink: 95 * (scale / 100), // 95%

  revenueFactor: 20 * (scale / 100), // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.fdusd - 2), // 0.01 FDUSD
}

export const sbUsdtInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink: 85 * (scale / 100), // 85%
  highKink: 95 * (scale / 100), // 95%

  revenueFactor: 20 * (scale / 100), // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.sbUsdt - 2), // 0.01 USDT
}

export const mUsdInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.mUsd - 2), // 0.01 MUSD
}

export const usdyInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(3), // 3%
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(10), // 10%
  borrowRateOnHighKink: getRatePerSec(25), // 25%
  maxBorrowRate: getRatePerSec(150), // 150%

  midKink: 85 * (scale / 100), // 85%
  highKink: 95 * (scale / 100), // 95%

  revenueFactor: 20 * (scale / 100), // 20%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.usdy - 2), // 0.01 USDY
}

export const blubInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight: (scale * 1.25), // 125%
  scale,
  minBorrowAmount: 13 * 10 ** (coinDecimals.blub + 6), // 13M BLUB
};

export const nsInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight: (scale * 1.25), // 125%
  scale,
  minBorrowAmount: 10 ** (coinDecimals.ns - 1), // 0.1 NS
};

export const haedalInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 40 * (scale / 100), // 40%
  borrowWeight, // 100%
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haedal - 1), // 0.1 NS
};

export const walInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wal - 2), // 0.01 WAL
};

export const wWalInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.wWal - 2), // 0.01 wWAL
};

export const haWalInterestModel: InterestModel = {
  baseBorrowRatePerSec: getRatePerSec(20),
  interestRateScale,

  borrowRateOnMidKink: getRatePerSec(30), // 30%
  borrowRateOnHighKink: getRatePerSec(50), // 50%
  maxBorrowRate: getRatePerSec(600), // 600%

  midKink, // 80%
  highKink, // 90%

  revenueFactor: 30 * (scale / 100), // 30%
  borrowWeight, // 1
  scale,
  minBorrowAmount: 10 ** (coinDecimals.haWal - 2), // 0.01 haWAL
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
  wormholeBtc: wormholeBtcInterestModel,
  wormholeSol: wormholeSolInterestModel,
  nativeUsdc: nativeUsdcInterestModel,
  sbEth: sbEthInterestModel,
  deep: deepInterestModel,
  fud: fudInterestModel,
  fdusd: fdusdInterestModel,
  sbUsdt: sbUsdtInterestModel,
  blub: blubInterestModel,
  sbwBTC: sbwBtcInterestModel,
  mUsd: mUsdInterestModel,
  ns: nsInterestModel,
  usdy: usdyInterestModel,
  wal: walInterestModel,
  haedal: haedalInterestModel,
  wWal: wWalInterestModel,
  haWal: haWalInterestModel,
}
