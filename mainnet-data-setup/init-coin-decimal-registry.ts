import { SuiTxBlock } from '@scallop-io/sui-kit';
import { decimalsRegistryTxBuilder } from '../contracts/libs/coin_decimals_registry';
import { wormholeUsdcCoinMetadataId, wormholeUsdcType  } from './chain-data'

export const initCoinDecimalRegistry = (suiTxBlock: SuiTxBlock) => {
  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: wormholeUsdcType, metadataId: wormholeUsdcCoinMetadataId },
  ];

  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(
      suiTxBlock,
      pair.metadataId,
      pair.type,
    );
  });
}
