import { PublishResultParser } from "@scallop-io/sui-package-kit";

export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    authorizedPriceRegistryId: '',
    authorizedPriceRegistryCapId: '',
  };
  const registryType = `${res.packageId}::authorized_price_registry::AuthorizedPriceRegistry`;
  const registryCapType = `${res.packageId}::authorized_price_registry::AuthorizedPriceRegistryCap`;
  for (const obj of res.created) {
    if (obj.type === registryType) {
      parsedResult.authorizedPriceRegistryId = obj.objectId;
    } else if (obj.type === registryCapType) {
      parsedResult.authorizedPriceRegistryCapId = obj.objectId;
    }
  }
  return parsedResult;
}
