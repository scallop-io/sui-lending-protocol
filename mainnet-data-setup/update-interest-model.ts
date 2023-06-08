import { SUI_TYPE_ARG } from '@mysten/sui.js'
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import { protocolTxBuilder, InterestModel } from '../contracts/protocol';
import { wormholeUsdcType } from './chain-data'


export const updateInterestModel = (suiTxBlock: SuiTxBlock) => {
  
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
        baseRatePerSec: 15854986000, // 5 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        lowSlope: 167 * 10 ** 14, // 1.67
        kink: 6 * 10 ** 15, // 0.6
        highSlope: 95 * 10 ** 16, // 95
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 9, // 10SUI
        borrow_weight: 125 * 10 ** 14, // 1.25
      }
    },
    {
      type: wormholeUsdcType,
      interestModel: {
        baseRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * 1000
        lowSlope: 278 * 10 ** 14, // 2.78
        kink: 6 * 10 ** 15, // 0.6
        highSlope: 7667 * 10 ** 14, // 76.67
        marketFactor: 5 * 10 ** 14, // 5%
        scale: 10 ** 16,
        minBorrowAmount: 10 ** 6,
        borrow_weight: 10 ** 16, // 1
      },
    },
  ];
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.updateInterestModel(
      suiTxBlock,
      pair.interestModel,
      pair.type,
    );
  });
}

const tx = new SuiTxBlock();
updateInterestModel(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error);

