import { SUI_CLOCK_OBJECT_ID, SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class AuthorizedPriceRuleTxBuilder {
  constructor(
    public packageId: string,
    public registryId: string,
    public registryCapId: string,
  ) {}

  // @dev `addr` must be passed through `pure.address`: sui-kit's arg converter routes any
  // valid Sui address string to `tx.object(...)`, which the `address` parameter would reject
  addAuthorizedAddress(tx: SuiTxBlock, addr: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::add_authorized_address`,
      [this.registryId, this.registryCapId, tx.pure.address(addr)],
    );
  }

  removeAuthorizedAddress(tx: SuiTxBlock, addr: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::remove_authorized_address`,
      [this.registryId, this.registryCapId, tx.pure.address(addr)],
    );
  }

  // @dev `minPrice` and `maxPrice` are USD prices expressed as `value / 10^decimals`
  // example: minPrice = 150, decimals = 2 => $1.50
  // @dev `decimals` must be passed through `pure.u8`: sui-kit's arg converter serializes every
  // bare number as u64, which the `decimals: u8` parameter would reject as invalid BCS bytes
  setPriceRange(
    tx: SuiTxBlock,
    minPrice: string | number | bigint,
    maxPrice: string | number | bigint,
    decimals: number,
    coinType: string,
  ) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::set_price_range`,
      [
        this.registryId,
        this.registryCapId,
        tx.pure.u64(minPrice),
        tx.pure.u64(maxPrice),
        tx.pure.u8(decimals),
      ],
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
  setPriceValidDuration(tx: SuiTxBlock, durationSecs: string | number | bigint) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::set_price_valid_duration`,
      [this.registryId, this.registryCapId, tx.pure.u64(durationSecs)],
    );
  }

  // @dev `price` is a USD price with 9 decimals (price_feed::decimals()).
  // Prefer a string/bigint: a 9-decimal price above ~$9,007,199 exceeds JS Number.MAX_SAFE_INTEGER.
  // The tx sender must be an authorized address, and the price must be within the safe range
  setPrice(tx: SuiTxBlock, price: string | number | bigint, coinType: string) {
    tx.moveCall(
      `${this.packageId}::authorized_price_registry::set_price`,
      [this.registryId, tx.pure.u64(price), SUI_CLOCK_OBJECT_ID],
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
