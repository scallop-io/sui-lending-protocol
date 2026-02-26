import { SUI_CLOCK_OBJECT_ID, SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class CustomAfsuiRuleTxBuilder {
  constructor(
    public packageId: string,
    public oracleConfigId: string,
    public oracleAdminCapId: string,
    public wormholeStateId: string,
    public pythStateId: string,
    public afStakedSuiVaultId: string,
    public afSafeId: string,
  ) {}

  updateOracleConfig(tx: SuiTxBlock, pythInfoObjectId: string, priceConfidenceToleranceBps: number) {
    tx.moveCall(
      `${this.packageId}::oracle_config::update_oracle_config`,
      [this.oracleConfigId, this.oracleAdminCapId, pythInfoObjectId, priceConfidenceToleranceBps],
      []
    );
  }

  // @params: `tolerance` - percentage of tolerance
  // example: tolerance = 2 => 2%
  calculatePriceConfidenceTolerance(tolerance: number) {
    const PriceConfidenceToleranceDenominator = 10_000;
    return Math.floor(tolerance / 100 * PriceConfidenceToleranceDenominator);
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
        this.oracleConfigId,
        this.afStakedSuiVaultId,
        this.afSafeId,
        SUI_CLOCK_OBJECT_ID
      ],
      [coinType]
    );
  }
}
