import type { PublishResultParser } from '@scallop-io/sui-package-kit'
export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    marketId: '',
    adminCapId: '',
    versionId: '',
    versionCapId: '',
  };
  const marketType = `${res.packageId}::market::Market`;
  const adminCapType = `${res.packageId}::app::AdminCap`;
  const versionType = `${res.packageId}::version::Version`;
  const versionCapType = `${res.packageId}::version::VersionCap`;
  for (const obj of res.created) {
    if (obj.type === marketType) {
      parsedResult.marketId = obj.objectId;
    } else if (obj.type === adminCapType) {
      parsedResult.adminCapId = obj.objectId;
    } else if (obj.type === versionType) {
      parsedResult.versionId = obj.objectId;
    } else if (obj.type === versionCapType) {
      parsedResult.versionCapId = obj.objectId;
    }
  }
  return parsedResult;
}
