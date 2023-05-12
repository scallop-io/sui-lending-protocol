import { PublishResultParser } from "@scallop-io/sui-package-kit"

export const publishResultParser: PublishResultParser = (res) => {
  const packageId = res.packageId;
  const output: Record<string, { metadataId: string, treasuryId: string }> = {};
  // a regex for pattern: `0x2::coin::CoinMetadata<${pkgId}::${coinName}::${coinName.toUpperCase()}>`
  const metadataTypeRegex = new RegExp(`coin::CoinMetadata<${packageId}::(\\w+)::(\\w+)>`);
  const treasuryTypeRegex = new RegExp(`${packageId}::(\\w+)::Treasury`);
  for (const obj of res.created) {
    if (metadataTypeRegex.test(obj.type)) {
      const coinName = metadataTypeRegex.exec(obj.type)![1];
      output[coinName] = { ...output[coinName], metadataId: obj.objectId };
    } else if (treasuryTypeRegex.test(obj.type)) {
      const coinName = treasuryTypeRegex.exec(obj.type)![1];
      output[coinName] = { ...output[coinName], treasuryId: obj.objectId };
    }
  }
  return output;
}
