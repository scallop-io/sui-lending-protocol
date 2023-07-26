import { SUI_TYPE_ARG } from '@mysten/sui.js'
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder, RiskModel, InterestModel, OutflowLimiterModel } from '../contracts/protocol';
import { wormholeUsdcType } from './chain-data'


export const initMarket = (suiTxBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    {
      type: SUI_TYPE_ARG,
      riskModel: {
        collateralFactor: 60,
        liquidationFactor: 80,
        liquidationPanelty: 5,
        liquidationDiscount: 4,
        scale: 100,
        maxCollateralAmount: 10 ** 15, // 1 million SUI
      }
    },
    {
      type: wormholeUsdcType,
      riskModel: {
        collateralFactor: 80,
        liquidationFactor: 90,
        liquidationPanelty: 5,
        liquidationDiscount: 4,
        scale: 100,
        maxCollateralAmount: 10 ** 12, // 1 million USDC
      }
    },
  ];

  const scale = 10 ** 12;
  const interestRateScale = 10 ** 7;
  let secsPerYear = 365 * 24 * 60 * 60;
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
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
        minBorrowAmount: 10 ** 7, // 0.01 SUI
      }
    },
    {
      type: wormholeUsdcType,
      interestModel: {
        // baseBorrowRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * (10 ** 7)
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
        minBorrowAmount: 10 ** 4, // 0.01 USDC
      },
    },
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    {
      type: SUI_TYPE_ARG,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9), // 1 million SUI per day
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: wormholeUsdcType,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 6), // 1 million USDC per day
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
      type: wormholeUsdcType,
      value: 1,
      scale: 1,
    }
  ];

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
