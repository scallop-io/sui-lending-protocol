import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { buildMultiSigTx } from './multi-sig';

function addLockKey(keyType: string) {
  const tx = new SuiTxBlock();
  protocolTxBuilder.addLockKey(tx, keyType);
  return buildMultiSigTx(tx);
}

const keyType = '0x41c0788f4ab64cf36dc882174f467634c033bf68c3c1b5ef9819507825eb510b::incentive_account::IncentiveProgramLockKey';
addLockKey(keyType).then(console.log);