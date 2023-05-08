import { SuiTxBlock } from '@scallop-io/sui-kit';
import _ids from './ids.json';

type TestCoin = 'eth' | 'usdc' | 'usdt' | 'btc';
export class TestCoinTxBuilder {
  constructor(
    public packageId: string,
    public treasuryIds: Record<TestCoin, string>,
  ) {}

  mint(
    suiTxBlock: SuiTxBlock,
    amount: number,
    coinName: TestCoin,
  ) {
    const mintTarget = `${this.packageId}::${coinName}::mint`;
    return suiTxBlock.moveCall(
      mintTarget,
      [this.treasuryIds[coinName], amount],
    );
  }
}

export const ids = _ids;

const treasuryIds = {
  eth: ids.eth.treasuryId,
  usdc: ids.usdc.treasuryId,
  usdt: ids.usdt.treasuryId,
  btc: ids.btc.treasuryId,
}
export const testCoinTxBuilder = new TestCoinTxBuilder(ids.packageId, treasuryIds);
