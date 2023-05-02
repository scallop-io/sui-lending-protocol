import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { suiKit } from './sui-kit-instance';

export const registerSwitchboardOracles = async (
  pkgId: string,
  switchboardRegistryCapId: string,
  switchboardRegistryId: string,
  ethAggregatorId: string,
  usdcAggregatorId: string,
  usdtAggregatorId: string,
  btcAggregatorId: string,
  suiAggregatorId: string,
) => {
  const tx = new SuiTxBlock();
  const registerTarget = `${pkgId}::switchboard_registry::register_aggregator`;
  tx.moveCall(
    registerTarget,
    [switchboardRegistryCapId, switchboardRegistryId, ethAggregatorId],
    [`${pkgId}::eth::ETH`],
  );
  tx.moveCall(
    registerTarget,
    [switchboardRegistryCapId, switchboardRegistryId, usdcAggregatorId],
    [`${pkgId}::usdc::USDC`],
  );
  tx.moveCall(
    registerTarget,
    [switchboardRegistryCapId, switchboardRegistryId, usdtAggregatorId],
    [`${pkgId}::usdt::USDT`],
  );
  tx.moveCall(
    registerTarget,
    [switchboardRegistryCapId, switchboardRegistryId, btcAggregatorId],
    [`${pkgId}::btc::BTC`],
  );
  tx.moveCall(
    registerTarget,
    [switchboardRegistryCapId, switchboardRegistryId, suiAggregatorId],
    [`0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI`],
  );
  tx.txBlock.setGasBudget(10 ** 10);
  return suiKit.signAndSendTxn(tx);
}
