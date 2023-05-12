import type { PublishResultParser } from '@scallop-io/sui-package-kit'
export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    coinDecimalsRegistryId: '',
  };
  const registryType = `${res.packageId}::coin_decimals_registry::CoinDecimalsRegistry`;
  for (const obj of res.created) {
    if (obj.type === registryType) {
      parsedResult.coinDecimalsRegistryId = obj.objectId;
    }
  }
  return parsedResult;
}
