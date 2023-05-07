import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-kit-instance';
import { DecimalsRegistryTxBuilder } from './txbuilders/decimals-registry-txbuilder';
import { ProtocolTxBuilder, RiskModel, InterestModel, OutflowLimiterModel } from './txbuilders/protocol-txbuilder';
import type { ProtocolPublishData } from '../package-publish/extract-objects-from-publish-results';


export const initMarketForTest = async (data: ProtocolPublishData) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    {
      type: `${data.packageIds.TestCoin}::eth::ETH`,
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
      type: `${data.packageIds.TestCoin}::btc::BTC`,
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
      type: `${data.packageIds.TestCoin}::usdc::USDC`,
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
      type: `${data.packageIds.TestCoin}::usdt::USDT`,
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
      type: `${data.packageIds.TestCoin}::usdc::USDC`,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
    {
      type: `${data.packageIds.TestCoin}::usdt::USDT`,
      outflowLimit: {
        outflowLimit: 10 ** (6 + 9),
        outflowCycleDuration: 60 * 60 * 24,
        outflowSegmentDuration: 60 * 30,
      }
    },
  ]

  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: `${data.packageIds.TestCoin}::eth::ETH`, metadataId: data.testCoinData.eth.metadataId },
    { type: `${data.packageIds.TestCoin}::btc::BTC`, metadataId: data.testCoinData.btc.metadataId },
    { type: `${data.packageIds.TestCoin}::usdt::USDT`, metadataId: data.testCoinData.usdt.metadataId },
    { type: `${data.packageIds.TestCoin}::usdc::USDC`, metadataId: data.testCoinData.usdc.metadataId },
  ]

  const decimalsRegistryTxBuilder = new DecimalsRegistryTxBuilder(
    data.packageIds.Protocol,
    data.marketData.coinDecimalsRegistryId,
  );

  const protocolTxBuilder = new ProtocolTxBuilder(
    data.packageIds.Protocol,
    data.marketData.adminCapId,
    data.marketData.marketId,
  );

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
