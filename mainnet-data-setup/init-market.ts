import { SUI_TYPE_ARG } from '@mysten/sui.js'
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
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

  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
        baseRatePerSec: 159, // 5 * (10 ** 11) / (365 * 24 * 3600) / 100
        lowSlope: 167 * 10 ** 9, // 1.67
        kink: 6 * 10 ** 10, // 0.6
        highSlope: 95 * 10 ** 11, // 95
        marketFactor: 5 * 10 ** 9, // 5%
        scale: 10 ** 11,
        minBorrowAmount: 10 ** 10, // 10SUI
        borrow_weight: 125 * 10 ** 9, // 1.25
      }
    },
    {
      type: wormholeUsdcType,
      interestModel: {
        baseRatePerSec: 95, // 3 * (10 ** 11) / (365 * 24 * 3600) / 100
        lowSlope: 278 * 10 ** 9, // 2.78
        kink: 6 * 10 ** 10, // 0.6
        highSlope: 7667 * 10 ** 9, // 76.67
        marketFactor: 5 * 10 ** 9, // 5%
        scale: 10 ** 11,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 11, // 1
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
  ]

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
}
