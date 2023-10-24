import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';

disableAssets().then(console.log);

function disableAssets() {
  const tx = new SuiTxBlock();
  // disable base assets for 'btc', 'sol', 'apt'
  protocolTxBuilder.setBaseAssetActiveState(tx, false, coinTypes.wormholeBtc);
  protocolTxBuilder.setBaseAssetActiveState(tx, false, coinTypes.wormholeSol);
  protocolTxBuilder.setBaseAssetActiveState(tx, false, coinTypes.wormholeApt);
  // disable collateral assets for 'btc', 'sol', 'apt'
  protocolTxBuilder.setCollateralActiveState(tx, false, coinTypes.wormholeBtc);
  protocolTxBuilder.setCollateralActiveState(tx, false, coinTypes.wormholeSol);
  protocolTxBuilder.setCollateralActiveState(tx, false, coinTypes.wormholeApt);
  return buildMultiSigTx(tx);
}
