import * as path from "path";
import { createRequire } from "module";
import { fileURLToPath } from "url";

// ESM does not provide CJS globals; publish-result JSON is loaded by computed path
const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import { networkType } from "sui-elements";
import { AuthorizedPriceRuleTxBuilder } from "./typescript/tx-builder";

export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const authorizedPriceRuleTxBuilder = new AuthorizedPriceRuleTxBuilder(
  publishResult.packageId,
  publishResult.authorizedPriceRegistryId,
  publishResult.authorizedPriceRegistryCapId,
);

export const authorizedPriceRuleStructType = `${publishResult.packageId}::rule::Rule`;
