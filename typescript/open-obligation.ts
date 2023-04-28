import { SuiTransactionBlockResponse, getObjectChanges } from "@mysten/sui.js";
import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { suiKit } from './sui-kit-instance';

export const openObligation = async (
  packageId: string,
  marketId: string,
) => {
  const tx = new SuiTxBlock();
  const ethCoinType = `${packageId}::eth::ETH`;
  const [obligation, obligationKey, hotPotato] = tx.moveCall(
    `${packageId}::open_obligation::open_obligation`,
    []
  );
  const coins = await suiKit.selectCoinsWithAmount(100, ethCoinType);
  const [sendCoin, leftCoin] = tx.takeAmountFromCoins(coins, 100);
  tx.moveCall(
    `${packageId}::deposit_collateral::deposit_collateral`,
    [obligation, marketId, sendCoin],
    [ethCoinType]
  );
  tx.moveCall(
    `${packageId}::open_obligation::return_obligation`,
    [obligation, hotPotato],
  );
  tx.transferObjects([leftCoin], suiKit.currentAddress());
  tx.transferObjects([obligationKey], suiKit.currentAddress());
  const res = await  suiKit.signAndSendTxn(tx);
  return parseOpenObligationResponse(res)
}

export const parseOpenObligationResponse = (suiResponse: SuiTransactionBlockResponse) => {
  const objectChanges = getObjectChanges(suiResponse);
  const parseRes = {
    obligationId: '',
    obligationKeyId: '',
  }
  if (objectChanges) {
    for (const change of objectChanges) {
      if (change.type === 'created' && change.objectType.endsWith('obligation::Obligation')) {
        parseRes.obligationId = change.objectId;
      } else if (change.type === 'created' && change.objectType.endsWith('obligation::ObligationKey')) {
        parseRes.obligationKeyId = change.objectId;
      }
    }
  }
  return parseRes;
}
