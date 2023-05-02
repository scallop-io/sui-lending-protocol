import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import type { NetworkType } from "@scallop-dao/sui-kit";
import { SuiPackagePublisher } from "@scallop-dao/sui-package-kit";
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
export const publishPackageEnforce = async (
  pkgPath: string,
  // These are the names in the [addresses] section of Move.toml with value "0x0" when publishing the package for the first time
  placeholderNames: string[],
  signer: RawSigner,
  networkType: NetworkType
) => {
  const tomlPath = path.join(pkgPath, "Move.toml");
  const moveToml = parseMoveToml(tomlPath);
  placeholderNames = placeholderNames.length ? placeholderNames : [moveToml.package.name.toLowerCase()];
  moveToml.package["published-at"] = undefined;
  for (const placeholderName of placeholderNames) {
    moveToml.addresses[placeholderName] = "0x0";
  }
  writeMoveToml(moveToml, tomlPath);

  const publishResult = await publishPackage(pkgPath, signer);
  if (!publishResult.packageId) throw new Error(`Package ${moveToml.package.name} publish failed`);
  moveToml.package["published-at"] = publishResult.packageId;
  moveToml.package[`${networkType}-published-at`] = publishResult.packageId;
  const addresses = moveToml.addresses;
  for (const placeholderName of placeholderNames) {
    addresses[placeholderName] = publishResult.packageId;
  }
  moveToml[`${networkType}-addresses`] = addresses;
  writeMoveToml(moveToml, tomlPath);
}

// If the package has been published under the networkType, we just update the Move.toml file, and do not publish the package again
export const publishPackageWithCache = async (
  pkgPath: string,
  // These are the names in the [addresses] section of Move.toml with value "0x0" when publishing the package for the first time
  placeholderNames: string[],
  signer: RawSigner,
  networkType: NetworkType
) => {
  const tomlPath = path.join(pkgPath, "Move.toml");
  const moveToml = parseMoveToml(tomlPath);
  placeholderNames = placeholderNames.length ? placeholderNames : [moveToml.package.name.toLowerCase()];

  const isPublished = Boolean(moveToml[`${networkType}-addresses`]) && Boolean(moveToml.package[`${networkType}-published-at`].length);
  if (isPublished) {
    console.log(`Package ${moveToml.package.name} has been published under ${networkType}, skip publishing`.cyan);
    moveToml.addresses = moveToml[`${networkType}-addresses`] as Record<string, any>;
    moveToml.package["published-at"] = moveToml.package[`${networkType}-published-at`];
    writeMoveToml(moveToml, tomlPath);
  } else {
    await publishPackageEnforce(pkgPath, placeholderNames, signer, networkType);
  }
}

// Remove the published-at, reset [addresses], and remove [localhost-addresses] if exists
export const cleanAfterPublish = (pkgPath: string, placeholderNames: string[]) => {
  const tomlPath = path.join(pkgPath, "Move.toml");
  const moveToml = parseMoveToml(tomlPath);
  placeholderNames = placeholderNames.length ? placeholderNames : [moveToml.package.name.toLowerCase()];
  moveToml.package["published-at"] = undefined;
  moveToml.package["localhost-published-at"] = undefined;
  for (const placeholderName of placeholderNames) {
    moveToml.addresses[placeholderName] = "0x0";
  }
  moveToml["localhost-addresses"] = undefined;
  writeMoveToml(moveToml, tomlPath);
}
