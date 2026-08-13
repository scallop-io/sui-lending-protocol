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

  // @dev `price` is a USD price with 9 decimals (price_feed::decimals())
  // The tx sender must be an authorized address, and the price must be within the safe range
  setPriceAsPrimary(
    tx: SuiTxBlock,
    request: SuiTxArg,
    price: string | number,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::rule::set_price_as_primary`,
      [request, this.registryId, price, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }

  // @dev `price` is a USD price with 9 decimals (price_feed::decimals())
  // The tx sender must be an authorized address, and the price must be within the safe range
  setPriceAsSecondary(
    tx: SuiTxBlock,
    request: SuiTxArg,
    price: string | number,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::rule::set_price_as_secondary`,
      [request, this.registryId, price, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }
}
