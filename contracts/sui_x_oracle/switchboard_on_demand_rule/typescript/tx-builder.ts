import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js";
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";
import { addSwitchboardUpdateInTx } from "./get_switchboard-client";

export class SwitchboardOnDemandRuleTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
    public registryCapId: string
  ) {}

  async updateAggregator(
    tx: SuiTxBlock,
    switchboardAggregatorId: string,
    rpc: string
  ) {
    return addSwitchboardUpdateInTx(tx, switchboardAggregatorId, rpc);
  }

  registerSwitchboardAggregator(
    tx: SuiTxBlock,
    aggregator: SuiTxArg,
    coinType: string
  ) {
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
    coinType: string
  ) {
    tx.moveCall(
      `${this.packageId}::rule::set_price`,
      [request, aggregator, this.registryId, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }
}
