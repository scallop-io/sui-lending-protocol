import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { FlashloanFees } from './flashloan-fees';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';


export const update = () => {
  const suiTxBlock = new SuiTxBlock();

  const flashloanFeeList: { type: string, fee: number }[] = [
    {type: coinTypes.sui, fee: FlashloanFees.sui},
    {type: coinTypes.afSui, fee: FlashloanFees.afSui},
    {type: coinTypes.haSui, fee: FlashloanFees.haSui},
    {type: coinTypes.vSui, fee: FlashloanFees.vSui},
    {type: coinTypes.cetus, fee: FlashloanFees.cetus},
    {type: coinTypes.wormholeUsdc, fee: FlashloanFees.wormholeUsdc},
    {type: coinTypes.wormholeUsdt, fee: FlashloanFees.wormholeUsdt},
    {type: coinTypes.wormholeEth, fee: FlashloanFees.wormholeEth},
    {type: coinTypes.sca, fee: FlashloanFees.sca},
  ];

  flashloanFeeList.forEach(pair => {
    protocolTxBuilder.setFlashloanFee(suiTxBlock, pair.fee, pair.type);
  });

  return buildMultiSigTx(suiTxBlock);
}

update().then(console.log).catch(console.error).finally(() => process.exit(0));
