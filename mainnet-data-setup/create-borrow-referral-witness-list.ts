import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { buildMultiSigTx } from './multi-sig';
import { suiKit } from 'sui-elements';

function createBorrowReferralWitnessList() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.createReferralWitnessList(tx);
  return buildMultiSigTx(tx);
}

createBorrowReferralWitnessList().then(console.log);
