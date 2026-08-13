import { SUI_CLOCK_OBJECT_ID, SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class AuthorizedPriceRuleTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
    public registryCapId: string,
  ) {}

  addAuthorizedAddress(tx: SuiTxBlock, addr: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::add_authorized_address`,
      [this.registryId, this.registryCapId, addr],
    );
  }

  removeAuthorizedAddress(tx: SuiTxBlock, addr: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::remove_authorized_address`,
      [this.registryId, this.registryCapId, addr],
    );
  }

  // @dev `minPrice` and `maxPrice` are USD prices expressed as `value / 10^decimals`
  // example: minPrice = 150, decimals = 2 => $1.50
  setPriceRange(
    tx: SuiTxBlock,
    minPrice: string | number,
    maxPrice: string | number,
    decimals: number,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::set_price_range`,
      [this.registryId, this.registryCapId, minPrice, maxPrice, decimals],
      [coinType]
    );
  }

  removePriceRange(tx: SuiTxBlock, coinType: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::remove_price_range`,
      [this.registryId, this.registryCapId],
      [coinType]
    );
  }

  // @dev `durationSecs` is how long a stored price stays valid, in seconds
  setPriceValidDuration(tx: SuiTxBlock, durationSecs: string | number) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::set_price_valid_duration`,
      [this.registryId, this.registryCapId, durationSecs],
    );
  }

  // @dev `price` is a USD price with 9 decimals (price_feed::decimals())
  // The tx sender must be an authorized address, and the price must be within the safe range
  setPrice(tx: SuiTxBlock, price: string | number, coinType: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::set_price`,
      [this.registryId, price, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }

  // Pulls the stored price into the x_oracle price update request.
  // Aborts if the stored price is stale, so make sure `setPrice` was called recently
  setPriceAsPrimary(tx: SuiTxBlock, request: SuiTxArg, coinType: string) {
    tx.moveCall(
      `${this.packageId}::rule::set_price_as_primary`,
      [request, this.registryId, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }

  setPriceAsSecondary(tx: SuiTxBlock, request: SuiTxArg, coinType: string) {
    tx.moveCall(
      `${this.packageId}::rule::set_price_as_secondary`,
      [request, this.registryId, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }
}
