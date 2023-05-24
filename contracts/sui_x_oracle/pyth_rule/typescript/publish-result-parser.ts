import { PublishResultParser } from "@scallop-io/sui-package-kit";

export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    pythRegistryId: '',
    pythRegistryCapId: '',
  };
  const pythRegistryType = `${res.packageId}::pyth_registry::PythRegistry`;
  const pythRegistryCapType = `${res.packageId}::pyth_registry::PythRegistryCap`;
  for (const obj of res.created) {
    if (obj.type === pythRegistryType) {
      parsedResult.pythRegistryId = obj.objectId;
    } else if (obj.type === pythRegistryCapType) {
      parsedResult.pythRegistryCapId = obj.objectId;
    }
  }
  return parsedResult;
}
