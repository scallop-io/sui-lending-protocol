import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { ProtocolTxBuilder } from './txbuilders/protocol-txbuilder';
import { TestCoinTxBuilder } from './txbuilders/test-coin-txbuilder';
import type { ProtocolPublishData } from '../package-publish/extract-objects-from-publish-results';
import { suiKit } from '../sui-kit-instance';

export const supplyBaseAsset = async (data: ProtocolPublishData) => {
  const protocolTxBuilder = new ProtocolTxBuilder(
    data.packageIds.Protocol,
    data.marketData.adminCapId,
    data.marketData.marketId,
  );

  const testCoinTxBuilder = new TestCoinTxBuilder(
    data.packageIds.TestCoin,
    {
      eth: data.testCoinData.eth.treasuryId,
      usdc: data.testCoinData.usdc.treasuryId,
      usdt: data.testCoinData.usdt.treasuryId,
      btc: data.testCoinData.btc.treasuryId,
    }
  );

  const tx = new SuiTxBlock();

  let usdcCoin = testCoinTxBuilder.mint(tx, 10 ** 14, 'usdc');
  let usdtCoin = testCoinTxBuilder.mint(tx, 10 ** 15, 'usdt');

  protocolTxBuilder.supplyBaseAsset(tx, usdcCoin, `${data.packageIds.TestCoin}::usdc::USDC`);
  protocolTxBuilder.supplyBaseAsset(tx, usdtCoin, `${data.packageIds.TestCoin}::usdt::USDT`);

  const res = await suiKit.signAndSendTxn(tx);
  return res;
}
