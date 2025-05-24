import { ProtocolWhitelistTxBuilder } from 'contracts/protocol_whitelist/typescript/tx-builder';
import { buildMultiSigTx } from './multi-sig';
import { SuiTxBlock } from '@scallop-io/sui-kit';

stopAll().then(console.log);

async function stopAll() {
  const pkgId = '0x4c262d9343dac53ecb28f482a2a3f62c73d0ebac5b5f03d57383d56ff219acdf';
  const publisherId = '0x57aef959c136baf9232fdb642cd491a33d60095d32847953961047992f6737c7';
  const marketId = '0xa757975255146dc9686aa823b7838b507f315d704f428cbadad2f4ea061939d9';
  const whitelistBuilder = new ProtocolWhitelistTxBuilder(pkgId, publisherId, marketId);

  const tx = new SuiTxBlock();
  whitelistBuilder.rejectAll(tx);

  return buildMultiSigTx(tx);
}