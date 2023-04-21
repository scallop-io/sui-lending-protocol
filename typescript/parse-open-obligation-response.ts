import { SuiTransactionBlockResponse, getObjectChanges } from "@mysten/sui.js";

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
