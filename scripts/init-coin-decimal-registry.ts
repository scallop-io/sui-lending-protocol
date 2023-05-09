import { SuiTxBlock } from '@scallop-io/sui-kit';
import { testCoinTypes, ids as testCoinIds  } from '../test_coin';
import { decimalsRegistryTxBuilder } from '../libs/coin_decimals_registry';

export const initCoinDecimalRegistry = (suiTxBlock: SuiTxBlock) => {

  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: testCoinTypes.eth, metadataId: testCoinIds.eth.metadataId },
    { type: testCoinTypes.btc, metadataId: testCoinIds.btc.metadataId },
    { type: testCoinTypes.usdt, metadataId: testCoinIds.usdt.metadataId },
    { type: testCoinTypes.usdc, metadataId: testCoinIds.usdc.metadataId },
  ]

  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(
      suiTxBlock,
      pair.metadataId,
      pair.type,
    );
  });
}
