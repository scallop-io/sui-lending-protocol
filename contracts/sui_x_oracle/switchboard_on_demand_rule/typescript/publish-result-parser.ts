import { PublishResultParser } from "@scallop-io/sui-package-kit";

export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    switchboardRegistryId: '',
    switchboardRegistryCapId: '',
  };
  const switchboardRegistryType = `${res.packageId}::switchboard_registry::SwitchboardRegistry`;
  const switchboardRegistryCapType = `${res.packageId}::switchboard_registry::SwitchboardRegistryCap`;
  for (const obj of res.created) {
    if (obj.type === switchboardRegistryType) {
      parsedResult.switchboardRegistryId = obj.objectId;
    } else if (obj.type === switchboardRegistryCapType) {
      parsedResult.switchboardRegistryCapId = obj.objectId;
    }
  }
  return parsedResult;
}
