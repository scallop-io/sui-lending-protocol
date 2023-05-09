import * as path from "path"
import { suiKit, networkType } from "sui-elements"
import { publishPackageWithCache, writeAsJson } from "contract-deployment"

export const publishPackage = async () => {
  const pkgPath = path.join(__dirname, ".");
  const res = await publishPackageWithCache(pkgPath, suiKit.getSigner(), networkType)
  if (!res) return;

  const pkgId = res.publishResult.packageId;
  const output: Record<string, { metadataId: string, treasuryId: string }> = {};
  // a regex for pattern: `0x2::coin::CoinMetadata<${pkgId}::${coinName}::${coinName.toUpperCase()}>`
  const metadataTypeRegex = new RegExp(`coin::CoinMetadata<${pkgId}::(\\w+)::(\\w+)>`);
  const treasuryTypeRegex = new RegExp(`${pkgId}::(\\w+)::Treasury`);
  for (const obj of res.publishResult.created) {
    if (metadataTypeRegex.test(obj.type)) {
      const coinName = metadataTypeRegex.exec(obj.type)![1];
      output[coinName] = { ...output[coinName], metadataId: obj.objectId };
    } else if (treasuryTypeRegex.test(obj.type)) {
      const coinName = treasuryTypeRegex.exec(obj.type)![1];
      output[coinName] = { ...output[coinName], treasuryId: obj.objectId };
    }
  }
  writeAsJson(output, path.join(__dirname, `./ids.${networkType}.json`));
}

publishPackage().then(console.log).catch(console.error)
