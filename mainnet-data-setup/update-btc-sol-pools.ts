import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
  BorrowFee,
} from '../contracts/protocol';
import { SupplyLimits } from './supply-limits';
import { borrowFees } from './borrow-fee';
import { coinTypes } from './chain-data';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { buildMultiSigTx } from './multi-sig';
import {riskModels} from "./risk-models";
import {interestModels} from "./interest-models";


export const updateBtcSol = () => {
  const suiTxBlock = new SuiTxBlock();

  // Update supply limits
  protocolTxBuilder.setSupplyLimit(suiTxBlock, SupplyLimits.wormholeSol, coinTypes.wormholeSol);
  protocolTxBuilder.setSupplyLimit(suiTxBlock, SupplyLimits.wormholeBtc, coinTypes.wormholeBtc);

  // Update borrow fees
  protocolTxBuilder.updateBorrowFee(suiTxBlock, borrowFees.wormholeSol, coinTypes.wormholeSol);
  protocolTxBuilder.updateBorrowFee(suiTxBlock, borrowFees.wormholeBtc, coinTypes.wormholeBtc);

  // Update outflow limits
  protocolTxBuilder.updateOutflowLimit(suiTxBlock, outflowRateLimiters.wormholeSol, coinTypes.wormholeSol);
  protocolTxBuilder.updateOutflowLimit(suiTxBlock, outflowRateLimiters.wormholeBtc, coinTypes.wormholeBtc);

  // Update risk models
  protocolTxBuilder.updateRiskModel(suiTxBlock, riskModels.wormholeSol, coinTypes.wormholeSol);
  protocolTxBuilder.updateRiskModel(suiTxBlock, riskModels.wormholeBtc, coinTypes.wormholeBtc);

  // Update interest models
  protocolTxBuilder.updateInterestModel(suiTxBlock, interestModels.wormholeSol, coinTypes.wormholeSol);
  protocolTxBuilder.updateInterestModel(suiTxBlock, interestModels.wormholeBtc, coinTypes.wormholeBtc);

  // Enable assets
  protocolTxBuilder.setBaseAssetActiveState(suiTxBlock, true, coinTypes.wormholeSol);
  protocolTxBuilder.setBaseAssetActiveState(suiTxBlock, true, coinTypes.wormholeBtc);
  protocolTxBuilder.setCollateralActiveState(suiTxBlock, true, coinTypes.wormholeSol);
  protocolTxBuilder.setCollateralActiveState(suiTxBlock, true, coinTypes.wormholeBtc);

  return buildMultiSigTx(suiTxBlock);
}

updateBtcSol().then(console.log).catch(console.error).finally(() => process.exit(0));
