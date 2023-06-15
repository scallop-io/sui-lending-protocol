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

  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
        baseRatePerSec: 15854986000, // 5 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        interestRateScale: 1000,
        lowSlope: 167 * 10 ** 14, // 1.67
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 95 * 10 ** 16, // 95
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 10, // 10SUI
        borrow_weight: 125 * 10 ** 14, // 1.25
      }
    },
    {
      type: testCoinTypes.usdc,
      interestModel: {
        baseRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        interestRateScale: 1000,
        lowSlope: 278 * 10 ** 14, // 2.78
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 7667 * 10 ** 14, // 76.67
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 16, // 1
      },
    },
    {
      type: testCoinTypes.usdt,
      interestModel: {
        baseRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        interestRateScale: 1000,
        lowSlope: 278 * 10 ** 14, // 2.78
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 7667 * 10 ** 14, // 76.67
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 16, // 1
      },
    },
    {
      type: testCoinTypes.btc,
      interestModel: {
        baseRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        interestRateScale: 1000,
        lowSlope: 278 * 10 ** 14, // 2.78
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 7667 * 10 ** 14, // 76.67
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 16, // 1
      },
    },
    {
      type: testCoinTypes.eth,
      interestModel: {
        baseRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        interestRateScale: 1000,
        lowSlope: 278 * 10 ** 14, // 2.78
        kink: 8 * 10 ** 15, // 0.8
        highSlope: 7667 * 10 ** 14, // 76.67
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 8,
        borrow_weight: 10 ** 16, // 1
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
