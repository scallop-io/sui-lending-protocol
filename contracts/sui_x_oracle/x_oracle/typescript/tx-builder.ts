import { SUI_CLOCK_OBJECT_ID, SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";
export class XOracleTxBuilder {
  constructor(
    public packageId: string,
    public xOracleId: string,
    public xOracleCapId: string,
  ) { }

  initRulesV2DF(tx: SuiTxBlock) {
    tx.moveCall(
      `${this.packageId}::x_oracle::init_rules_df_if_not_exist`,
      [this.xOracleCapId, this.xOracleId],
      []
    );
  }

  addPrimaryPriceUpdateRuleV2(tx: SuiTxBlock, coinType: string, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::add_primary_price_update_rule_v2`,
      [this.xOracleId, this.xOracleCapId],
      [coinType, ruleType]
    );
  }

  removePrimaryPriceUpdateRuleV2(tx: SuiTxBlock, coinType: string, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::remove_primary_price_update_rule_v2`,
      [this.xOracleId, this.xOracleCapId],
      [coinType, ruleType]
    );
  }

  addSecondaryPriceUpdateRuleV2(tx: SuiTxBlock, coinType: string, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::add_secondary_price_update_rule_v2`,
      [this.xOracleId, this.xOracleCapId],
      [coinType, ruleType]
    );
  }

  removeSecondaryPriceUpdateRuleV2(tx: SuiTxBlock, coinType: string, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::remove_secondary_price_update_rule_v2`,
      [this.xOracleId, this.xOracleCapId],
      [coinType, ruleType]
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
