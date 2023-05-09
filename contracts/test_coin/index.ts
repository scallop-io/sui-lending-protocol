import { SuiTxBlock } from '@scallop-io/sui-kit';
import { networkType } from "../../sui-elements";
export const ids = require(`./ids.${networkType}.json`);

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

const treasuryIds = {
  eth: ids.eth.treasuryId,
  usdc: ids.usdc.treasuryId,
  usdt: ids.usdt.treasuryId,
  btc: ids.btc.treasuryId,
}
export const testCoinTxBuilder = new TestCoinTxBuilder(ids.packageId, treasuryIds);

export const testCoinTypes = {
  btc: `${ids.packageId}::btc::BTC`,
  eth: `${ids.packageId}::eth::ETH`,
  usdt: `${ids.packageId}::usdt::USDT`,
  usdc: `${ids.packageId}::usdc::USDC`
}
