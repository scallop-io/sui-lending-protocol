import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js"
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit"
import _ids from "./ids.json"

export class PythRuleTxBuilder {
  constructor(
    public packageId: string,
    public pythRegistryId: string,
    public pythRegistryCapId: string
  ) {
  }

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
    wormholeState: SuiTxArg,
    pythState: SuiTxArg,
    pythPriceInfoObject: SuiTxArg,
    vaaBuf: SuiTxArg,
    coinType: string,
  ) {
    let [updateFee] = tx.splitSUIFromGas([1]);
    tx.moveCall(
      `${this.packageId}::rule::set_price`,
      [
        request,
        wormholeState,
        pythState,
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

export const ids = _ids;
export const pythRuleTxBuilder = new PythRuleTxBuilder(ids.packageId, ids.pythRegistryId, ids.pythRegistryCapId);
