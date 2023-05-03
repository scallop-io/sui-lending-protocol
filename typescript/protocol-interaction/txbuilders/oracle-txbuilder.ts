import { SuiTxBlock } from "@scallop-dao/sui-kit"

export class OracleTxBuilder {
  constructor(
    public packageId: string,
    public switchboardRegistryId: string,
    public switchboardRegistryAdminCapId: string,
    public switchboardBundleId: string,
  ) {}

  registrySwitchboardAggregator(
    suiTxBlock: SuiTxBlock,
    aggregatorId: string,
    coinType: string,
  ) {
    const registrySwitchboardAggregatorTarget = `${this.packageId}::switchboard_registry::register_aggregator`;
    suiTxBlock.moveCall(
      registrySwitchboardAggregatorTarget,
      [
        this.switchboardRegistryAdminCapId,
        this.switchboardRegistryId,
        aggregatorId,
      ],
      [coinType],
    );
  }

  bundleSwitchboardAggregators(
    suiTxBlock: SuiTxBlock,
    aggregatorId: string,
    coinType: string,
  ) {
    const bundleSwitchboardAggregatorsTarget = `${this.packageId}::switchboard_adaptor::bundle_switchboard_aggregators`;
    suiTxBlock.moveCall(
      bundleSwitchboardAggregatorsTarget,
      [
        this.switchboardBundleId,
        this.switchboardRegistryId,
        aggregatorId,
      ],
      [coinType],
    );
  }

  getPrice(
    suiTxBlock: SuiTxBlock,
    coinType: string,
  ) {
    const getTypeTarget = `${this.packageId}::multi_oracle_strategy::get_type`;
    const typeName = suiTxBlock.moveCall(getTypeTarget, [], [coinType]);

    const getPriceTarget = `${this.packageId}::multi_oracle_strategy::get_price`;
    suiTxBlock.moveCall(
      getPriceTarget,
      [this.switchboardBundleId, typeName]
    );
  }
}
