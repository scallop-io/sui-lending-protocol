import { SuiTransactionBlockResponse, getObjectChanges } from "@mysten/sui.js";
import { SuiTxBlock } from '@scallop-io/sui-kit';
import { ProtocolTxBuilder } from './txbuilders/protocol-txbuilder';
import type { ProtocolPublishData } from '../package-publish/extract-objects-from-publish-results';
import { suiKit } from '../sui-kit-instance';

export const openObligation = async (data: ProtocolPublishData) => {
  const tx = new SuiTxBlock();
  const ethCoinType = `${data.packageIds.TestCoin}::eth::ETH`;

  const protocolTxBuilder = new ProtocolTxBuilder(
    data.packageIds.Protocol,
    data.marketData.adminCapId,
    data.marketData.marketId,
  );

  await protocolTxBuilder.openObligationAndAddCollateral(tx, 10 ** 10, ethCoinType);

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
