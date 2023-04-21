import { SuiKit, NetworkType } from "@scallop-dao/sui-kit";
import { SuiPackagePublisher } from "@scallop-dao/sui-package-kit";

export const publishPackage = async (pkgPath: string, secretKey: string, networkType: NetworkType) => {
  const suiKit = new SuiKit({ secretKey, networkType });

  const publisher = new SuiPackagePublisher();
  const signer = suiKit.getSigner();
  const gasBudget = 3 * 10 ** 9;
  return await publisher.publishPackage(pkgPath, signer, {
    gasBudget,
    withUnpublishedDependencies: true,
    skipFetchLatestGitDeps: true
  });
}
