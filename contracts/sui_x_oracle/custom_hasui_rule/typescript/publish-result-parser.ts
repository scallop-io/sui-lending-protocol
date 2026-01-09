import { PublishResultParser } from "@scallop-io/sui-package-kit";

export const publishResultParser: PublishResultParser = (res) => {
  const parsedResult = {
    oracleConfigId: '',
    oracleAdminCapId: '',
  };
  const oracleConfigType = `${res.packageId}::oracle_config::OracleConfig`;
  const oracleAdminCapType = `${res.packageId}::oracle_config::OracleAdminCap`;
  for (const obj of res.created) {
    if (obj.type === oracleConfigType) {
      parsedResult.oracleConfigId = obj.objectId;
    } else if (obj.type === oracleAdminCapType) {
      parsedResult.oracleAdminCapId = obj.objectId;
    }
  }
  return parsedResult;
}
