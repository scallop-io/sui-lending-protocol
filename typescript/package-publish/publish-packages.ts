import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import type { NetworkType } from "@scallop-io/sui-kit";
import { SuiPackagePublisher } from "@scallop-io/sui-package-kit";
import { parseMoveToml, writeMoveToml } from "./toml";

const publishPackage = async (pkgPath: string, signer: RawSigner) => {
  const publisher = new SuiPackagePublisher();
  const gasBudget = 10 ** 9;
  return await publisher.publishPackage(pkgPath, signer, {
    gasBudget,
    withUnpublishedDependencies: false,
    skipFetchLatestGitDeps: true
  });
}

// Publish the package even if it has been published before for the networkType
export const publishPackageAndWriteToml = async (
  pkgPath: string,
  signer: RawSigner,
  networkType: NetworkType
) => {
  const tomlPath = path.join(pkgPath, "Move.toml");
  const moveToml = parseMoveToml(tomlPath);

  const publishResult = await publishPackage(pkgPath, signer);
  if (!publishResult.packageId) throw new Error(`Package ${moveToml.package.name} publish failed`);
  moveToml.package["published-at"] = publishResult.packageId;
  moveToml.package[`${networkType}-published-at`] = publishResult.packageId;
  const addresses = moveToml.addresses;
  for (const key in addresses) {
    addresses[key] = publishResult.packageId;
  }
  moveToml[`${networkType}-addresses`] = addresses;
  writeMoveToml(moveToml, tomlPath);

  return { publishResult, packageName: moveToml.package.name };
}

// If the package has been published under the networkType, we just update the Move.toml file, and do not publish the package again
export const publishPackageWithCache = async (
  pkgPath: string,
  signer: RawSigner,
  networkType: NetworkType
) => {
  const tomlPath = path.join(pkgPath, "Move.toml");
  const moveToml = parseMoveToml(tomlPath);
  const isPublishedForNetwork = Boolean(moveToml[`${networkType}-addresses`]) && Boolean(moveToml.package[`${networkType}-published-at`].length);
  const isPublished = Boolean(moveToml.package["published-at"]);
  if (isPublishedForNetwork) {
    console.log(`Package ${moveToml.package.name} has been published under ${networkType}, skip publishing`.cyan);
    moveToml.addresses = moveToml[`${networkType}-addresses`] as Record<string, any>;
    moveToml.package["published-at"] = moveToml.package[`${networkType}-published-at`];
    writeMoveToml(moveToml, tomlPath);
  } else if (isPublished) {
    console.log(`Package ${moveToml.package.name} has been published, skip publishing`.cyan);
  } else {
    return await publishPackageAndWriteToml(pkgPath, signer, networkType);
  }
}
