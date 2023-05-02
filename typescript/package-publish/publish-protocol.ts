import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { publishPackageWithCache, cleanAfterPublish } from "./publish-packages";
import { suiKit, networkType } from "../sui-kit-instance";

// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const publishProtocol = async (
  packagePathList: { pkgPath: string, placeholderNames?: string[] }[],
  signer: RawSigner
) => {
  for (const pkg of packagePathList) {
    const pkgPath = pkg.pkgPath;
    const placeholderNames = pkg.placeholderNames || [];
    await publishPackageWithCache(pkgPath, placeholderNames, signer, networkType);
  }
  cleanTomlsAfterPublish(packagePathList);
}

export const cleanTomlsAfterPublish = (
  packagePathList: { pkgPath: string, placeholderNames?: string[] }[]
) => {
  for (const pkg of packagePathList) {
    const pkgPath = pkg.pkgPath;
    const placeholderNames = pkg.placeholderNames || [];
    cleanAfterPublish(pkgPath, placeholderNames);
  }
}

const mathPkgPath = path.join(__dirname, "../../math");
const xPkgPath = path.join(__dirname, "../../x");
const whitelistPkgPath = path.join(__dirname, "../../whitelist");
const switchboardPkgPath = path.join(__dirname, "../../switchboard");
const testCoinPkgPath = path.join(__dirname, "../../test_coin");
const oraclePkgPath = path.join(__dirname, "../../oracle");
const protocolPkgPath = path.join(__dirname, "../../protocol");
const protocolQueryPkgPath = path.join(__dirname, "../../query");

const protocolPackageList = [
  { pkgPath: mathPkgPath },
  { pkgPath: xPkgPath },
  { pkgPath: whitelistPkgPath },
  { pkgPath: switchboardPkgPath, placeholderNames: ['switchboard'] },
  { pkgPath: testCoinPkgPath, placeholderNames: ['test_coin'] },
  { pkgPath: oraclePkgPath },
  { pkgPath: protocolPkgPath },
  { pkgPath: protocolQueryPkgPath, placeholderNames: ['protocol_query'] }
];

const signer = suiKit.getSigner();
publishProtocol(protocolPackageList, signer).then(() => {
  console.log("protocol published");
}).catch((err) => {
  console.error(err);
  process.exit(1);
});
