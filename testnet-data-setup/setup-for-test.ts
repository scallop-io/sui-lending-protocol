import * as path from "path";
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { suiKit, packagePublisher } from "sui-elements";
import {
  publishResultParser as testCoinResultParser,
} from  "contracts/test_coin/typescript/publish-result-parser";

import {
  publishResultParser as decimalsRegistryResultParser,
} from "contracts/libs/coin_decimals_registry/typescript/publish-result-parser";


export const setupForTestnet = async () => {
  // Publish the packages
  const packageBatch: PackageBatch = [
    {
      packagePath: path.join(__dirname, "../contracts/test_coin"),
      option: { publishResultParser: testCoinResultParser }
    },
    {
      packagePath: path.join(__dirname, "../contracts/libs/coin_decimals_registry"),
      option: { publishResultParser: decimalsRegistryResultParser }
    },
  ];
  await packagePublisher.publishPackageBatch(packageBatch, suiKit.getSigner());
}

setupForTestnet();
