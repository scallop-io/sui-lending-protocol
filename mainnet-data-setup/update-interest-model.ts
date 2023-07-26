import { SUI_TYPE_ARG } from '@mysten/sui.js'
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import {protocolTxBuilder, InterestModel} from '../contracts/protocol';
import { wormholeUsdcType } from './chain-data'


export const updateInterestModel = (suiTxBlock: SuiTxBlock) => {

  const scale = 10 ** 12;
  const interestRateScale = 10 ** 7;
  let secsPerYear = 365 * 24 * 60 * 60;
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    {
      type: SUI_TYPE_ARG,
      interestModel: {
        // baseBorrowRatePerSec: 15854986000, // 5 * (10 ** 12) / (365 * 24 * 3600) / 100 * (10 ** 7)
        baseBorrowRatePerSec: 0,
        interestRateScale,

        borrowRateOnMidKink: Math.floor(10 * (scale / 100) * interestRateScale / secsPerYear), // 10%
        borrowRateOnHighKink: Math.floor(100 * (scale / 100) * interestRateScale / secsPerYear), // 100%
        maxBorrowRate: Math.floor(300 * (scale / 100) * interestRateScale / secsPerYear), // 300%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: scale, // 1
        scale,
        minBorrowAmount: 10 ** 7, // 0.01 SUI
      }
    },
    {
      type: wormholeUsdcType,
      interestModel: {
        // baseBorrowRatePerSec: 9512937000, // 3 * (10 ** 16) / (365 * 24 * 3600) / 100 * (10 ** 7)
        baseBorrowRatePerSec: 0,
        interestRateScale,

        borrowRateOnMidKink: Math.floor(8 * (scale / 100) * interestRateScale / secsPerYear), // 8%
        borrowRateOnHighKink: Math.floor(50 * (scale / 100) * interestRateScale / secsPerYear), // 50%
        maxBorrowRate: Math.floor(150 * (scale / 100) * interestRateScale / secsPerYear), // 150%

        midKink: 60 * (scale / 100), // 60%
        highKink: 90 * (scale / 100), // 90%

        revenueFactor: 5 * (scale / 100), // 5%
        borrowWeight: scale, // 1
        scale,
        minBorrowAmount: 10 ** 4, // 0.01 USDC
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

