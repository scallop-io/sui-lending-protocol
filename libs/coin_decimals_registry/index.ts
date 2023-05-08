import { SuiTxBlock } from "@scallop-io/sui-kit";
import _ids from "./ids.json"

export class DecimalsRegistryTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
  ) {}
  registerDecimals(
    suiTxBlock: SuiTxBlock,
    coinMetadataId: string,
    coinType: string,
  ) {
    const registerDecimalsTarget = `${this.packageId}::coin_decimals_registry::register_decimals`;
    suiTxBlock.moveCall(
      registerDecimalsTarget,
      [this.registryId, coinMetadataId],
      [coinType],
    );
  }
}

export const decimalsRegistryTxBuilder = new DecimalsRegistryTxBuilder(_ids.packageId, _ids.coinDecimalsRegistryId);
export const ids = _ids;
