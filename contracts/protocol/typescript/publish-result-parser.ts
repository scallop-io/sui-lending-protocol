import type { PublishResultParser } from '@scallop-io/sui-package-kit'
export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    marketId: '',
    adminCapId: '',
  };
  const marketType = `${res.packageId}::market::Market`;
  const adminCapType = `${res.packageId}::app::AdminCap`;
  for (const obj of res.created) {
    if (obj.type === marketType) {
      parsedResult.marketId = obj.objectId;
    } else if (obj.type === adminCapType) {
      parsedResult.adminCapId = obj.objectId;
    }
  }
  return parsedResult;
}
