import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js";
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class SwitchboardTestTxBuilder {
  constructor(
    public packageId: string,
  ) { }

  createAggregator(tx: SuiTxBlock) {
    tx.moveCall(
      `${this.packageId}::admin::create_aggregator`,
      []
    );
  }

  setValue(tx: SuiTxBlock, aggregatorId: SuiTxArg, value: number, scale: number) {
    tx.moveCall(
      `${this.packageId}::admin::set_value`,
      [aggregatorId, value, scale, SUI_CLOCK_OBJECT_ID]
    );
  }
}
