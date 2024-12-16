import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { SupplyLimits } from './supply-limits';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';


export const updateSupplyLimits = () => {
  const suiTxBlock = new SuiTxBlock();

  const supplyLimitList: { type: string, limit: number }[] = [
    {type: coinTypes.deep, limit: SupplyLimits.deep},
    {type: coinTypes.fud, limit: SupplyLimits.fud},
  ];

  supplyLimitList.forEach(pair => {
    protocolTxBuilder.setSupplyLimit(suiTxBlock, pair.limit, pair.type);
  });

  return buildMultiSigTx(suiTxBlock);
}

updateSupplyLimits().then(console.log).catch(console.error).finally(() => process.exit(0));
