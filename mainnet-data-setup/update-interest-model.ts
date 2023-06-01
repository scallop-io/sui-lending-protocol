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

