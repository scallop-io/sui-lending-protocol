import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
  RiskModel,
  InterestModel,
  OutflowLimiterModel,
  BorrowFee
} from '../contracts/protocol';
import { riskModels } from './risk-models';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { coinMetadataIds, coinTypes } from './chain-data';
import { SupplyLimits } from './supply-limits';
import { BorrowLimits } from './borrow-limits';
import { borrowFees } from './borrow-fee';
import { FlashloanFees } from './flashloan-fees';
import { MULTI_SIG_ADDRESS } from './multi-sig';
import { decimalsRegistryTxBuilder } from 'contracts/libs/coin_decimals_registry';
import { suiKit } from 'sui-elements';

export const initMarket = async (suiTxBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.sui, riskModel: riskModels.sui },
    { type: coinTypes.nativeUsdc, riskModel: riskModels.nativeUsdc },
    { type: coinTypes.sca, riskModel: riskModels.sca },
  ];

  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.sui, interestModel: interestModels.sui },
    { type: coinTypes.nativeUsdc, interestModel: interestModels.nativeUsdc },
    { type: coinTypes.sca, interestModel: interestModels.sca },
    { type: coinTypes.deep, interestModel: interestModels.deep },
    { type: coinTypes.fud, interestModel: interestModels.fud },
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    { type: coinTypes.sui, outflowLimit: outflowRateLimiters.sui },
    { type: coinTypes.nativeUsdc, outflowLimit: outflowRateLimiters.nativeUsdc },
    { type: coinTypes.sca, outflowLimit: outflowRateLimiters.sca },
    { type: coinTypes.deep, outflowLimit: outflowRateLimiters.deep },
    { type: coinTypes.fud, outflowLimit: outflowRateLimiters.fud },
  ];

  const supplyLimitList: { type: string, limit: number }[] = [
    {type: coinTypes.sca, limit: SupplyLimits.sca},
    {type: coinTypes.sui, limit: SupplyLimits.sui},
    {type: coinTypes.nativeUsdc, limit: SupplyLimits.nativeUsdc},
    {type: coinTypes.deep, limit: SupplyLimits.deep},
    {type: coinTypes.fud, limit: SupplyLimits.fud},
  ];

  const borrowLimitList: { type: string, limit: number }[] = [
    { type: coinTypes.sca, limit: BorrowLimits.sca },
    { type: coinTypes.sui, limit: BorrowLimits.sui },
    { type: coinTypes.nativeUsdc, limit: BorrowLimits.nativeUsdc },
    { type: coinTypes.deep, limit: BorrowLimits.deep },
    { type: coinTypes.fud, limit: BorrowLimits.fud },
  ];

  const isolatedAssetStatus: { type: string, status: boolean }[] = [
    { type: coinTypes.deep, status: true },
    { type: coinTypes.fud, status: true },
  ];

  const borrowFeePairs: { type: string, borrowFee: BorrowFee }[] = [
    {type: coinTypes.sui, borrowFee: borrowFees.sui},
    {type: coinTypes.sca, borrowFee: borrowFees.sca},
    {type: coinTypes.nativeUsdc, borrowFee: borrowFees.nativeUsdc},
    {type: coinTypes.deep, borrowFee: borrowFees.deep},
    {type: coinTypes.fud, borrowFee: borrowFees.fud},
  ];

  const flashloanFeeList: { type: string, fee: number }[] = [
    {type: coinTypes.sui, fee: FlashloanFees.sui},
    {type: coinTypes.nativeUsdc, fee: FlashloanFees.nativeUsdc},
    {type: coinTypes.sca, fee: FlashloanFees.sca},
    {type: coinTypes.deep, fee: FlashloanFees.deep},
    {type: coinTypes.fud, fee: FlashloanFees.fud},
  ];

  const decimalsList = [
    { type: coinTypes.sui, metadata: coinMetadataIds.sui },
    { type: coinTypes.nativeUsdc, metadata: coinMetadataIds.nativeUsdc },
    { type: coinTypes.sca, metadata: coinMetadataIds.sca },
    { type: coinTypes.deep, metadata: coinMetadataIds.deep },
    { type: coinTypes.fud, metadata: coinMetadataIds.fud },
  ];

  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(suiTxBlock, pair.riskModel, pair.type);
  });
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.addInterestModel(suiTxBlock, pair.interestModel, pair.type);
  });
  outflowLimitPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(suiTxBlock, pair.outflowLimit, pair.type);
  });
  supplyLimitList.forEach(pair => {
    protocolTxBuilder.setSupplyLimit(suiTxBlock, pair.limit, pair.type);
  });
  borrowLimitList.forEach(pair => {
    protocolTxBuilder.setBorrowLimit(suiTxBlock, pair.limit, pair.type);
  });
  isolatedAssetStatus.forEach(pair => {
    protocolTxBuilder.updateIsolatedAssetStatus(suiTxBlock, pair.status, pair.type);
  });
  borrowFeePairs.forEach(pair => {
    protocolTxBuilder.updateBorrowFee(suiTxBlock, pair.borrowFee, pair.type);
  });
  flashloanFeeList.forEach(pair => {
    protocolTxBuilder.setFlashloanFee(suiTxBlock, pair.fee, pair.type);
  });

  protocolTxBuilder.updateBorrowFeeRecipient(suiTxBlock, MULTI_SIG_ADDRESS);

  decimalsList.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(suiTxBlock, pair.metadata, pair.type);
  });

  const resp = await suiKit.signAndSendTxn(suiTxBlock);
  console.log(resp)
}

initMarket(new SuiTxBlock()).then(console.log).catch(console.error).finally(() => process.exit(0));