import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit"
import _ids from "./ids.json"

export class SwitchboardRuleTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
    public registryCapId: string
  ) {
  }

  registerSwitchboardAggregator(tx: SuiTxBlock, aggregator: SuiTxArg, coinType: string) {
    tx.moveCall(
      `${this.packageId}::switchboard_registry::register_switchboard_aggregator`,
      [this.registryId, this.registryCapId, aggregator],
      [coinType]
    );
  }

  setPrice(
    tx: SuiTxBlock,
    request: SuiTxArg,
    aggregator: SuiTxArg,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::rule::set_price`,
      [request, aggregator, this.registryId],
      [coinType]
    );
  }
}

export const ids = _ids;
export const switchboardRuleTxBuilder = new SwitchboardRuleTxBuilder(ids.packageId, ids.switchboardRegistry, ids.switchboardRegistryCapId);
