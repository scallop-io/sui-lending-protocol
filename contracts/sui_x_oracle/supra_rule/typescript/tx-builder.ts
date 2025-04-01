import { SUI_CLOCK_OBJECT_ID, SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class SupraRuleTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
    public registryCapId: string,
    public supraOracleId: string
  ) { }

  registerSupraPairId(tx: SuiTxBlock, pairId: number, coinType: string) {
    tx.moveCall(
      `${this.packageId}::supra_registry::register_supra_pair_id`,
      [this.registryId, this.registryCapId, pairId],
      [coinType]
    );
  }

  setPrice(
    tx: SuiTxBlock,
    request: SuiTxArg,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::rule::set_price`,
      [request, this.supraOracleId, this.registryId, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }
}
