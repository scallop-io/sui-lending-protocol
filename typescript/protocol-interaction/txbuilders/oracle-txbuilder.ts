import { SuiTxBlock } from "@scallop-dao/sui-kit"

export class OracleTxBuilder {
  constructor(
    public packageId: string,
    public switchboardRegistryId: string,
    public switchboardRegistryAdminCapId: string,
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
}
