import { RawSigner } from "@mysten/sui.js";
import { SuiPackagePublisher } from "@scallop-dao/sui-package-kit";

export const publishPackage = async (pkgPath: string, signer: RawSigner) => {
  const publisher = new SuiPackagePublisher();
  const gasBudget = 10 ** 10;
  return await publisher.publishPackage(pkgPath, signer, {
    gasBudget,
    withUnpublishedDependencies: true,
    skipFetchLatestGitDeps: true
  });
}