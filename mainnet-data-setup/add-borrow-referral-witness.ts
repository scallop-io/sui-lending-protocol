import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { buildMultiSigTx } from './multi-sig';
import { suiKit } from 'sui-elements';

function addBorrowReferralWitness(witnessType: string) {
  const tx = new SuiTxBlock();
  protocolTxBuilder.addBorrowReferralWitness(tx, witnessType);
  return suiKit.signAndSendTxn(tx);
}

const referralPkgId = '';
const witnessType = `${referralPkgId}::scallop_referral_program::REFERRAL_WITNESS`;
addBorrowReferralWitness(witnessType).then(console.log);
