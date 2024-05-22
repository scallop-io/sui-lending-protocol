import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { buildMultiSigTx } from './multi-sig';
import { suiKit } from 'sui-elements';

function createBorrowReferralWitnessList(witnessType: string) {
  const tx = new SuiTxBlock();
  protocolTxBuilder.createReferralWitnessList(tx, witnessType);
  return buildMultiSigTx(tx);
}

createBorrowReferralWitnessList(witnessType).then(console.log);
