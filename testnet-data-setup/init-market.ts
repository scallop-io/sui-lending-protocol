import { SUI_TYPE_ARG } from "@mysten/sui.js";
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import { testCoinTypes } from '../contracts/test_coin';
import { protocolTxBuilder, RiskModel, InterestModel, OutflowLimiterModel } from '../contracts/protocol';

export const initMarketForTest = (suiTxBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    {
      type: testCoinTypes.eth,
      riskModel: {
        collateralFactor: 80,
        liquidationFactor: 90,
        liquidationPanelty: 8,
        liquidationDiscount: 5,
        scale: 100,
        maxCollateralAmount: 10 ** 16,
      }
    },
    {
      type: testCoinTypes.btc,
      riskModel: {
        collateralFactor: 70,
        liquidationFactor: 80,
        liquidationPanelty: 8,
        liquidationDiscount: 5,
        scale: 100,
        maxCollateralAmount: 10 ** 13,
      }
    },
    {
      type: testCoinTypes.usdc,
      riskModel: {
        collateralFactor: 90,
        liquidationFactor: 95,
        liquidationPanelty: 3,
        liquidationDiscount: 2,
        scale: 100,
        maxCollateralAmount: 10 ** 17,
      }
    },
    {
      type: testCoinTypes.usdt,
      riskModel: {
        collateralFactor: 90,
        liquidationFactor: 95,
        liquidationPanelty: 3,
        liquidationDiscount: 2,
        scale: 100,
        maxCollateralAmount: 10 ** 17,
      }
    },
    {
      type: '0x2::sui::SUI',
      riskModel: {
        collateralFactor: 60,
        liquidationFactor: 70,
        liquidationPanelty: 10,
        liquidationDiscount: 7,
        scale: 100,
        maxCollateralAmount: 10 ** 17,
      }
    },
  ];

  const scale = 10 ** 12;
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
        baseBorrowRatePerSec: 0,
        interestRateScale: 10 ** 7,

        borrowRateOnMidKink: 10 * (scale / 100), // 10%
        borrowRateOnHighKink: 100 * (scale / 100), // 100%
        maxBorrowRate: 300 * (scale / 100), // 300%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: 125 * (scale / 100), // 1.25
        scale,
        minBorrowAmount: 10 ** 7, // 0.01SUI
      }
    },
    {
      type: testCoinTypes.usdc,
      interestModel: {
        baseBorrowRatePerSec: 0,
        interestRateScale: 10 ** 7,

        borrowRateOnMidKink: 8 * (scale / 100), // 8%
        borrowRateOnHighKink: 50 * (scale / 100), // 50%
        maxBorrowRate: 150 * (scale / 100), // 150%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: 100 * (scale / 100), // 1
        scale,
        minBorrowAmount: 10 ** 7, // 0.01 USDC
      },
    },
    {
      type: testCoinTypes.usdt,
      interestModel: {
        baseBorrowRatePerSec: 0,
        interestRateScale: 10 ** 7,

        borrowRateOnMidKink: 8 * (scale / 100), // 8%
        borrowRateOnHighKink: 50 * (scale / 100), // 50%
        maxBorrowRate: 150 * (scale / 100), // 150%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: 100 * (scale / 100), // 1
        scale,
        minBorrowAmount: 10 ** 9, // 0.01 USDT
      },
    },
    {
      type: testCoinTypes.btc,
      interestModel: {
        baseBorrowRatePerSec: 0,
        interestRateScale: 10 ** 7,

        borrowRateOnMidKink: 10 * (scale / 100), // 10%
        borrowRateOnHighKink: 100 * (scale / 100), // 100%
        maxBorrowRate: 300 * (scale / 100), // 300%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: 100 * (scale / 100), // 1
        scale,
        minBorrowAmount: 10 ** 9, // 0.01BTC
      },
    },
    {
      type: testCoinTypes.eth,
      interestModel: {
        baseBorrowRatePerSec: 0,
        interestRateScale: 10 ** 7,

        borrowRateOnMidKink: 10 * (scale / 100), // 10%
        borrowRateOnHighKink: 100 * (scale / 100), // 100%
        maxBorrowRate: 300 * (scale / 100), // 300%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: 100 * (scale / 100), // 1
        scale,
        minBorrowAmount: 10 ** 7, // 0.01ETH
      },
    },
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    {
      type: testCoinTypes.usdc,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: testCoinTypes.usdt,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: testCoinTypes.btc,
      outflowLimit: {
        outflowLimit: 10 ** (2 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: testCoinTypes.eth,
      outflowLimit: {
        outflowLimit: 10 ** (3 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: '0x2::sui::SUI',
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
  ];

  const incentiveRewardFactorPairs: { type: string, value: number, scale: number }[] = [
    {
      type: SUI_TYPE_ARG,
      value: 2,
      scale: 1,
    },
    {
      type: testCoinTypes.usdc,
      value: 1,
      scale: 1,
    },
    {
      type: testCoinTypes.usdt,
      value: 1,
      scale: 1,
    },
    {
      type: testCoinTypes.btc,
      value: 30000,
      scale: 1,
    },
    {
      type: testCoinTypes.eth,
      value: 2000,
      scale: 1,
    }
  ];

  protocolTxBuilder.addWhitelistAddress(
    suiTxBlock,
    suiKit.currentAddress(),
  );

  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(
      suiTxBlock,
      pair.riskModel,
      pair.type,
    );
  });
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.addInterestModel(
      suiTxBlock,
      pair.interestModel,
      pair.type,
    );
  });
  outflowLimitPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(
      suiTxBlock,
      pair.outflowLimit,
      pair.type,
    );
  });
  incentiveRewardFactorPairs.forEach(pair => {
    protocolTxBuilder.setIncentiveRewardFactor(
      suiTxBlock,
      pair.value,
      pair.scale,
      pair.type,
    )
  });
}
