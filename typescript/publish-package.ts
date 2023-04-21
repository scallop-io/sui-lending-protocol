import path from "path";
import dotenv from "dotenv";
import { SuiKit, NetworkType } from "@scallop-dao/sui-kit";
import { SuiPackagePublisher } from "@scallop-dao/sui-package-kit";
dotenv.config();

(async() => {
  const secretKey = process.env.SECRET_KEY;
  const networkType = (process.env.SUI_NETWORK_TYPE || 'devnet') as NetworkType;
  const suiKit = new SuiKit({ secretKey, networkType });

  const packagePath = path.join(__dirname, '../query');
  const publisher = new SuiPackagePublisher();
  const signer = suiKit.getSigner();
  const gasBudget = 10**10;
  const result = await publisher.publishPackage(packagePath, signer, { gasBudget, withUnpublishedDependencies: true, skipFetchLatestGitDeps: false });
  console.log('packageId: ' + result.packageId);
})();
