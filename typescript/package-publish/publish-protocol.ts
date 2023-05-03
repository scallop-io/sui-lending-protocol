import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackagePublishResult } from "@scallop-dao/sui-package-kit";
import { publishPackageWithCache, publishPackageEnforce, cleanAfterPublish } from "./publish-packages";
import { extractObjects } from "./extract-objects-from-publish-results";
import { suiKit, networkType } from "../sui-kit-instance";

const mathPkgPath = path.join(__dirname, "../../math");
const xPkgPath = path.join(__dirname, "../../x");
const whitelistPkgPath = path.join(__dirname, "../../whitelist");
const switchboardPkgPath = path.join(__dirname, "../../switchboard");
const testCoinPkgPath = path.join(__dirname, "../../test_coin");
const testSwitchboardAggregatorPkgPath = path.join(__dirname, "../../test_switchboard_aggregator");
const oraclePkgPath = path.join(__dirname, "../../oracle");
const protocolPkgPath = path.join(__dirname, "../../protocol");
const protocolQueryPkgPath = path.join(__dirname, "../../query");

const protocolPackageList = [
  { pkgPath: mathPkgPath },
  { pkgPath: xPkgPath },
  { pkgPath: whitelistPkgPath },
  { pkgPath: switchboardPkgPath, placeholderNames: ['switchboard'], enableCache: true },
  { pkgPath: testCoinPkgPath, placeholderNames: ['test_coin'] },
  { pkgPath: testSwitchboardAggregatorPkgPath, placeholderNames: ['test_switchboard_aggregator'] },
  { pkgPath: oraclePkgPath },
  { pkgPath: protocolPkgPath },
  { pkgPath: protocolQueryPkgPath, placeholderNames: ['protocol_query'] }
];
export const publishProtocol = async (
  signer: RawSigner,
) => {
  return await _publishProtocol(protocolPackageList, signer);
}

// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const _publishProtocol = async (
  packagePathList: { pkgPath: string, placeholderNames?: string[], enableCache?: boolean }[],
  signer: RawSigner
) => {
  const publishResults: { publishResult: PackagePublishResult, packageName: string }[] = [];
  for (const pkg of packagePathList) {
    const pkgPath = pkg.pkgPath;
    const placeholderNames = pkg.placeholderNames || [];
    const enableCache = pkg.enableCache ? pkg.enableCache : false;
    const res = enableCache
      ? await publishPackageWithCache(pkgPath, placeholderNames, signer, networkType)
      : await publishPackageEnforce(pkgPath, placeholderNames, signer, networkType)
    res && publishResults.push(res);
  }
  const ids = extractObjects(publishResults);
  cleanTomlsAfterPublish(packagePathList);
  return ids;
}

const cleanTomlsAfterPublish = (
  packagePathList: { pkgPath: string, placeholderNames?: string[] }[]
) => {
  for (const pkg of packagePathList) {
    const pkgPath = pkg.pkgPath;
    const placeholderNames = pkg.placeholderNames || [];
    cleanAfterPublish(pkgPath, placeholderNames);
  }
}
