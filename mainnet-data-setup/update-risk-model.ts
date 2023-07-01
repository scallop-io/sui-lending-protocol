import { SUI_TYPE_ARG } from '@mysten/sui.js'
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import {protocolTxBuilder, RiskModel} from '../contracts/protocol';
import { wormholeUsdcType } from './chain-data'


export const updateRiskModel = (suiTxBlock: SuiTxBlock) => {

  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    {
      type: SUI_TYPE_ARG,
      riskModel: {
        collateralFactor: 60,
        liquidationFactor: 50,
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

  riskModelPairs.forEach(pair => {
    protocolTxBuilder.updateRiskModel(
      suiTxBlock,
      pair.riskModel,
      pair.type,
    );
  });
}

const tx = new SuiTxBlock();
updateRiskModel(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error);

