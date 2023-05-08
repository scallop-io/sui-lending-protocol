import { SuiTxBlock } from '@scallop-io/sui-kit';
import { testCoinTxBuilder, ids as testCoinIds } from '../test_coin';
import { protocolTxBuilder } from '../protocol'
import { suiKit } from './sui-kit-instance';

export const supplyBaseAsset = async () => {
  const tx = new SuiTxBlock();

  let usdcCoin = testCoinTxBuilder.mint(tx, 10 ** 14, 'usdc');
  let usdtCoin = testCoinTxBuilder.mint(tx, 10 ** 15, 'usdt');

  protocolTxBuilder.supplyBaseAsset(tx, usdcCoin, `${testCoinIds.packageId}::usdc::USDC`);
  protocolTxBuilder.supplyBaseAsset(tx, usdtCoin, `${testCoinIds.packageId}::usdt::USDT`);

  const res = await suiKit.signAndSendTxn(tx);
  return res;
}
