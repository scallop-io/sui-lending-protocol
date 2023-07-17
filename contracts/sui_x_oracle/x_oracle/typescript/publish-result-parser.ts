import { PublishResultParser } from "@scallop-io/sui-package-kit";

export const publishResultParser: PublishResultParser = (res) => {
  console.log('xOracle res', res);
  const parsedResult = {
    xOracleId: '',
    xOracleCapId: '',
  };
  const xOracleType = `${res.packageId}::x_oracle::XOracle`;
  const xOracleCapType = `${res.packageId}::x_oracle::XOraclePolicyCap`;
  for (const obj of res.created) {
    if (obj.type === xOracleType) {
      parsedResult.xOracleId = obj.objectId;
    } else if (obj.type === xOracleCapType) {
      parsedResult.xOracleCapId = obj.objectId;
    }
  }
  console.log('xOracle parsedResult', parsedResult)
  return parsedResult;
}
