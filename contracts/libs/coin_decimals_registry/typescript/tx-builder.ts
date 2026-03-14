import { SuiTxArg, SuiTxBlock } from "@scallop-io/sui-kit";

export class DecimalsRegistryTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
  ) {}
  registerDecimals(
    suiTxBlock: SuiTxBlock,
    coinMetadataId: SuiTxArg | string,
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
