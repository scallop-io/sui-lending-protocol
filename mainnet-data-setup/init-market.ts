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
        collateralFactor: 70,
        liquidationFactor: 80,
        liquidationPanelty: 10,
        liquidationDiscount: 6,
        scale: 100,
        maxCollateralAmount: 10 ** 16,
      }
    },
    {
      type: wormholeUsdcType,
      riskModel: {
        collateralFactor: 80,
        liquidationFactor: 90,
        liquidationPanelty: 8,
        liquidationDiscount: 5,
        scale: 100,
        maxCollateralAmount: 10 ** 13,
      }
    },
  ];

  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
        baseRatePerSec: 6341958,
        lowSlope: 2 * 10 ** 16, // 2
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 2 * 10 ** 17, // 20
        marketFactor: 2 * 10 ** 14, // 2%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 16, // 1
      }
    },
    {
      type: wormholeUsdcType,
      interestModel: {
        baseRatePerSec: 6341958,
        lowSlope: 2 * 10 ** 16, // 2
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 2 * 10 ** 17, // 20
        marketFactor: 2 * 10 ** 14, // 2%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 16, // 1
      },
    },
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    {
      type: SUI_TYPE_ARG,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: wormholeUsdcType,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
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
