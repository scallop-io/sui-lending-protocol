import path from "path";
import dotenv from "dotenv";
import { NetworkType } from "@scallop-dao/sui-kit";
import { publishPackage } from "./publish-package";
import { dumpObjectIds } from "./dump-object-ids";
dotenv.config();

export const setup = async () => {
  const secretKey = process.env.SECRET_KEY || '';
  const networkType = (process.env.SUI_NETWORK_TYPE || 'devnet') as NetworkType;
  const packagePath = path.join(__dirname, '../query');
  const publishResult = await publishPackage(packagePath, secretKey, networkType);
  const objectIds = dumpObjectIds(publishResult);

}

setup();
