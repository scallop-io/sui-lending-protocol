import { SuiTxBlock } from '@scallop-io/sui-kit';

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
