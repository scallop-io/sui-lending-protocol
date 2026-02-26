import { SuiTxBlock } from '@scallop-io/sui-kit';
import { customAfsuiRuleTxBuilder } from 'contracts/sui_x_oracle';
import { oracles } from './asset-oracles';
import { suiKit } from 'sui-elements';

async function updateOracleConfig() {
  const tx = new SuiTxBlock();
  customAfsuiRuleTxBuilder.updateOracleConfig(tx, oracles.sui.pythPriceObjectId, customAfsuiRuleTxBuilder.calculatePriceConfidenceTolerance(1));
  const resp = await suiKit.signAndSendTxn(tx);
  console.log(resp)
}

updateOracleConfig().then(console.log);