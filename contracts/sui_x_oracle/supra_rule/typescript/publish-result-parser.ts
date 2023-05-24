import { PublishResultParser } from "@scallop-io/sui-package-kit";

export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    supraRegistryId: '',
    supraRegistryCapId: '',
  };
  const supraRegistryType = `${res.packageId}::supra_registry::SupraRegistry`;
  const supraRegistryCapType = `${res.packageId}::supra_registry::SupraRegistryCap`;
  for (const obj of res.created) {
    if (obj.type === supraRegistryType) {
      parsedResult.supraRegistryId = obj.objectId;
    } else if (obj.type === supraRegistryCapType) {
      parsedResult.supraRegistryCapId = obj.objectId;
    }
  }
  return parsedResult;
}
