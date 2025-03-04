import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js";
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class PythRuleTxBuilder {
  constructor(
    public packageId: string,
    public pythRegistryId: string,
    public pythRegistryCapId: string,
    public wormholeStateId: string,
    public pythStateId: string,
  ) {}

  // @dev `priceConfidenceTolerance` is a percentage value, the denominator is 10,000
  registerPythFeed(tx: SuiTxBlock, pythInfoObjectId: SuiTxArg, priceConfidenceTolerance: number, coinType: string) {
    tx.moveCall(
      `${this.packageId}::pyth_registry::register_pyth_feed`,
      [this.pythRegistryId, this.pythRegistryCapId, pythInfoObjectId, priceConfidenceTolerance],
      [coinType]
    );
  }

  setPriceAsPrimary(
    tx: SuiTxBlock,
    request: SuiTxArg,
    pythPriceInfoObject: SuiTxArg,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::rule::set_price_as_primary`,
      [
        request,
        this.pythStateId,
        pythPriceInfoObject,
        this.pythRegistryId,
        SUI_CLOCK_OBJECT_ID
      ],
      [coinType]
    );
  }
}
