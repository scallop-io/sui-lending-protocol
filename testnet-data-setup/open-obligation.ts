import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements'
import { testCoinTxBuilder, testCoinTypes } from '../contracts/test_coin';
import { protocolTxBuilder } from '../contracts/protocol'
import { publishResult as xOracleIds } from "contracts/sui_x_oracle/x_oracle"
import { publishResult as decimalsRegistryIds } from "contracts/libs/coin_decimals_registry"

import { updatePrice } from "contracts/sui_x_oracle/oracle-price"

export const supplyBaseAsset = (tx: SuiTxBlock) => {

  updatePrice(tx, testCoinTypes.eth);
  updatePrice(tx, testCoinTypes.usdc);
  updatePrice(tx, testCoinTypes.usdt);
  updatePrice(tx, testCoinTypes.btc);
  updatePrice(tx, '0x2::sui::SUI');
  let ethCoin = testCoinTxBuilder.mint(tx, 10 ** 9, 'eth');

  const [obligation, obligationKey, hotPotato] = protocolTxBuilder.openObligation(tx);
  protocolTxBuilder.addCollateral(tx, obligation, ethCoin, testCoinTypes.eth);
  let borrowedCoin = protocolTxBuilder.borrowBaseAsset(
    tx,
    obligation,
    obligationKey,
    decimalsRegistryIds.coinDecimalsRegistryId,
    10 ** 9,
    xOracleIds.xOracleId,
    testCoinTypes.usdc
  );
  protocolTxBuilder.returnObligation(tx, obligation, hotPotato);
  tx.transferObjects([borrowedCoin], suiKit.currentAddress());
  tx.transferObjects([obligationKey], suiKit.currentAddress());
}

const tx = new SuiTxBlock();
supplyBaseAsset(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error);
