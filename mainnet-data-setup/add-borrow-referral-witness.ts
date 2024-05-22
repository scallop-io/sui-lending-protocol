import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { buildMultiSigTx } from './multi-sig';
import { suiKit } from 'sui-elements';

function addBorrowReferralWitness(witnessType: string) {
  const tx = new SuiTxBlock();
  protocolTxBuilder.addReferralWitness(tx, witnessType);
  return buildMultiSigTx(tx);
}

const referralPkgId = '0x5658d4bf5ddcba27e4337b4262108b3ad1716643cac8c2054ac341538adc72ec';
const witnessType = `${referralPkgId}::scallop_referral_program::REFERRAL_WITNESS`;
addBorrowReferralWitness(witnessType).then(console.log);
