import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js";
import { SuiTxBlock } from "@scallop-dao/sui-kit";

export class TestSwitchboardAggregatorTxBuilder {
  constructor(
    public packageId: string,
  ) { }

  initAggregator(
    suiTxBlock: SuiTxBlock,
    name: string,
    value: number,
    scaleFactor: number,
  ) {
    const initAggregatorTarget = `${this.packageId}::test_switchboard_aggregator::init_aggregator`;
    suiTxBlock.moveCall(
      initAggregatorTarget,
      [name, value, scaleFactor, false, SUI_CLOCK_OBJECT_ID],
    );
  }

  setValue(
    suiTxBlock: SuiTxBlock,
    value: number,        // example the number 10 would be 10 * 10^dec (dec automatically scaled to 9)
    scaleFactor: number,   // example 9 would be 10^9, 10 = 1000000000
  ) {
    const setValueTarget = `${this.packageId}::test_switchboard_aggregator::set_value`;
    suiTxBlock.moveCall(
      setValueTarget,
      [value, scaleFactor, false],
    );
  }
}
