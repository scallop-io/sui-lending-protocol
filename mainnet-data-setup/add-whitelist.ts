import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from '../contracts/protocol';

export const addWhitelist = (tx: SuiTxBlock) => {
  const addresses = [
    '0x5e813e4c2504b76bfbef802411c11d1688b5d35f7a5c209e9eb4eb78780b322a',
    '0xcf78430b3c3942f90e16aafc422c4c40398a02bda2045492a66d183752a494b2',
    '0x43ca8481c5edc7d30fdd6462c9740dd038d3cbc5c13eede479566902cc579294',
    '0x652bac7cfca90729db59abafcf4fc088a213ef12237a2f9d56598684a379acbe',
    '0xa6e5e59eef4645c3ee8b48bcc2feaef543790e18bdabb15e3f765482d211305e'
  ];
  for (const address of addresses) {
    protocolTxBuilder.addWhitelistAddress(
      tx,
      address
    );
  }
  return tx;
}
