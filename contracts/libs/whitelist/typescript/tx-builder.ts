import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";
export class WhitelistTxBuilder {
  constructor(
    public packageId: string,
  ) {}

  addWhitelistAddress(
    suiTxBlock: SuiTxBlock,
    uid: SuiTxArg,
    address: string,
  ) {
    const addWhitelistAddressTarget = `${this.packageId}::whitelist::add_whitelist_address`;
    suiTxBlock.moveCall(
      addWhitelistAddressTarget,
      [uid, address],
    );
  }

  removeWhitelistAddress(
    suiTxBlock: SuiTxBlock,
    uid: SuiTxArg,
    address: string,
  ) {
    const removeWhitelistAddressTarget = `${this.packageId}::whitelist::remove_whitelist_address`;
    suiTxBlock.moveCall(
      removeWhitelistAddressTarget,
      [uid, address],
    );
  }

  allowAll(
    suiTxBlock: SuiTxBlock,
    uid: SuiTxArg,
  ) {
    const allowAllTarget = `${this.packageId}::whitelist::allow_all`;
    suiTxBlock.moveCall(
      allowAllTarget,
      [uid],
    );
  }

  rejectAll(
    suiTxBlock: SuiTxBlock,
    uid: SuiTxArg,
  ) {
    const rejectAllTarget = `${this.packageId}::whitelist::reject_all`;
    suiTxBlock.moveCall(
      rejectAllTarget,
      [uid],
    );
  }
}
