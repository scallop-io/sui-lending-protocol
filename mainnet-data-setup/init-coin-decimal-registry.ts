import { SuiTxBlock } from '@scallop-io/sui-kit';
import { decimalsRegistryTxBuilder } from '../contracts/libs/coin_decimals_registry';
import { coinTypes, coinMetadataIds } from './chain-data'

export const initCoinDecimalRegistry = (suiTxBlock: SuiTxBlock) => {
  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: coinTypes.wormholeUsdc, metadataId: coinMetadataIds.wormholeUsdc },
  ];

  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(
      suiTxBlock,
      pair.metadataId,
      pair.type,
    );
  });
}
