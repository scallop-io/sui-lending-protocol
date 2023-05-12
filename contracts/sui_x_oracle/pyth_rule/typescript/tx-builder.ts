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

  registerPythPriceInfoObject(tx: SuiTxBlock, pythInfoObjectId: SuiTxArg, coinType: string) {
    tx.moveCall(
      `${this.packageId}::pyth_registry::register_pyth_price_info_object`,
      [this.pythRegistryId, this.pythRegistryCapId, pythInfoObjectId],
      [coinType]
    );
  }

  setPrice(
    tx: SuiTxBlock,
    request: SuiTxArg,
    pythPriceInfoObject: SuiTxArg,
    vaaBuf: SuiTxArg,
    coinType: string,
  ) {
    let [updateFee] = tx.splitSUIFromGas([1]);
    tx.moveCall(
      `${this.packageId}::rule::set_price`,
      [
        request,
        this.wormholeStateId,
        this.pythStateId,
        pythPriceInfoObject,
        this.pythRegistryId,
        vaaBuf,
        updateFee,
        SUI_CLOCK_OBJECT_ID
      ],
      [coinType]
    );
  }
}
