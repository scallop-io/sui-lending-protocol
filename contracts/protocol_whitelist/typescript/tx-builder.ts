import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export class ProtocolWhitelistTxBuilder {
  constructor(
    public packageId: string,
    public scallopPublisherId: string,
    public marketId: string,
  ) { }

  addWhitelistAddress(
    txBlock: SuiTxBlock,
    address: string,
  ) {
    const target = `${this.packageId}::protocol_whitelist::add_whitelist_address`;
    txBlock.moveCall(
      target,
      [this.scallopPublisherId, this.marketId, address]
    );
  }

  removeWhitelistAddress(
    txBlock: SuiTxBlock,
    address: string,
  ) {
    const target = `${this.packageId}::protocol_whitelist::remove_whitelist_address`;
    txBlock.moveCall(
      target,
      [this.scallopPublisherId, this.marketId, address]
    );
  }

  allowAll(txBlock: SuiTxBlock) {
    const target = `${this.packageId}::protocol_whitelist::allow_all`;
    txBlock.moveCall(
      target,
      [this.scallopPublisherId, this.marketId]
    );
  }

  rejectAll(txBlock: SuiTxBlock) {
    const target = `${this.packageId}::protocol_whitelist::reject_all`;
    txBlock.moveCall(
      target,
      [this.scallopPublisherId, this.marketId]
    );
  }
}
