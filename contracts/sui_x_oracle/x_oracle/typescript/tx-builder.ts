import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js";
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";
export class XOracleTxBuilder {
  constructor(
    public packageId: string,
    public xOracleId: string,
    public xOracleCapId: string,
  ) {}

  addPrimaryPriceUpdateRule(tx: SuiTxBlock, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::add_primary_price_update_rule`,
      [this.xOracleId, this.xOracleCapId],
      [ruleType]
    );
  }

  removePrimaryPriceUpdateRule(tx: SuiTxBlock, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::remove_primary_price_update_rule`,
      [this.xOracleId, this.xOracleCapId],
      [ruleType]
    );
  }

  addSecondaryPriceUpdateRule(tx: SuiTxBlock, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::add_secondary_price_update_rule`,
      [this.xOracleId, this.xOracleCapId],
      [ruleType]
    );
  }

  removeSecondaryPriceUpdateRule(tx: SuiTxBlock, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::remove_secondary_price_update_rule`,
      [this.xOracleId, this.xOracleCapId],
      [ruleType]
    );
  }

  priceUpdateRequest(tx: SuiTxBlock, coinType: string) {
    return tx.moveCall(
      `${this.packageId}::x_oracle::price_update_request`,
      [this.xOracleId],
      [coinType]
    );
  }

  confirmPriceUpdateRequest(tx: SuiTxBlock, request: SuiTxArg, coinType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::confirm_price_update_request`,
      [this.xOracleId, request, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }
}
