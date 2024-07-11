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
    {type: coinTypes.sui, limit: SupplyLimits.sui},
    {type: coinTypes.afSui, limit: SupplyLimits.afSui},
    {type: coinTypes.haSui, limit: SupplyLimits.haSui},
    {type: coinTypes.vSui, limit: SupplyLimits.vSui},
    {type: coinTypes.cetus, limit: SupplyLimits.cetus},
    {type: coinTypes.wormholeUsdc, limit: SupplyLimits.wormholeUsdc},
    {type: coinTypes.wormholeUsdt, limit: SupplyLimits.wormholeUsdt},
    {type: coinTypes.wormholeEth, limit: SupplyLimits.wormholeEth},
    {type: coinTypes.sca, limit: SupplyLimits.sca},
  ];

  supplyLimitList.forEach(pair => {
    protocolTxBuilder.setSupplyLimit(suiTxBlock, pair.limit, pair.type);
  });

  return buildMultiSigTx(suiTxBlock);
}

updateSupplyLimits().then(console.log).catch(console.error).finally(() => process.exit(0));
