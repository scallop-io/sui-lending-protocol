import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";
import _ids from "./ids.json";

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
  addSecondaryPriceUpdateRule(tx: SuiTxBlock, ruleType: string) {
    tx.moveCall(
      `${this.packageId}::x_oracle::add_secondary_price_update_rule`,
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
      [this.xOracleId, request],
      [coinType]
    );
  }
}

export const ids = _ids;
export const xOracleTxBuilder = new XOracleTxBuilder(ids.packageId, ids.xOracleId, ids.xOracleCapId);
