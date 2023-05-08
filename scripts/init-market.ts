import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from './sui-kit-instance';
import testCoinIds from '../test_coin/ids.json';
import { decimalsRegistryTxBuilder } from '../libs/coin_decimals_registry';
import { protocolTxBuilder, RiskModel, InterestModel, OutflowLimiterModel } from '../protocol';

export const initMarketForTest = async () => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    {
      type: `${testCoinIds.packageId}::eth::ETH`,
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
      type: `${testCoinIds.packageId}::btc::BTC`,
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
      type: `${testCoinIds.packageId}::usdc::USDC`,
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
      type: `${testCoinIds.packageId}::usdt::USDT`,
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
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    {
      type: `${testCoinIds.packageId}::usdc::USDC`,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: `${testCoinIds.packageId}::usdt::USDT`,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
  ]

  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: `${testCoinIds.packageId}::eth::ETH`, metadataId: testCoinIds.eth.metadataId },
    { type: `${testCoinIds.packageId}::btc::BTC`, metadataId: testCoinIds.btc.metadataId },
    { type: `${testCoinIds.packageId}::usdt::USDT`, metadataId: testCoinIds.usdt.metadataId },
    { type: `${testCoinIds.packageId}::usdc::USDC`, metadataId: testCoinIds.usdc.metadataId },
  ]

  const suiTxBlock = new SuiTxBlock();

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
  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(
      suiTxBlock,
      pair.metadataId,
      pair.type,
    );
  });
  suiTxBlock.txBlock.setGasBudget(10 ** 9);
  const txResponse = await suiKit.signAndSendTxn(suiTxBlock);
  return txResponse;
}
