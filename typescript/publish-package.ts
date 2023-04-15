import path from "path";
import dotenv from "dotenv";
import { SuiKit } from "@scallop-dao/sui-kit";
import { SuiPackagePublisher } from "@scallop-dao/sui-package-kit";
dotenv.config();

(async() => {
  const mnemonics = process.env.MNEMONICS;
  const networkType = (process.env.NETWORK_TYPE || 'devnet') as 'devnet' | 'testnet' | 'mainnet';
  const suiKit = new SuiKit({ mnemonics, networkType });

  const packagePath = path.join(__dirname, '../query');
  const publisher = new SuiPackagePublisher();
  const signer = suiKit.getSigner();
  const gasBudget = 10**9;
  const result = await publisher.publishPackage(packagePath, signer, { gasBudget });
  console.log('packageId: ' + result.packageId);
})();
