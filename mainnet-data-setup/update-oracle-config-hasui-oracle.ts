import { SuiTxBlock } from '@scallop-io/sui-kit';
import { customHasuiRuleTxBuilder } from 'contracts/sui_x_oracle';
import { oracles } from './asset-oracles';
import { suiKit } from 'sui-elements';

async function updateOracleConfig() {
  const tx = new SuiTxBlock();
  customHasuiRuleTxBuilder.updateOracleConfig(tx, oracles.sui.pythPriceObjectId, customHasuiRuleTxBuilder.calculatePriceConfidenceTolerance(1));
  const resp = await suiKit.signAndSendTxn(tx);
  console.log(resp)
}

updateOracleConfig().then(console.log);