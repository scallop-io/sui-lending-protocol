import dotenv from "dotenv";
import {
  fromBase64,
  getFullnodeUrl,
  type NetworkType,
  SuiKit,
  type Transaction,
} from "@scallop-io/sui-kit";
import { createRequire } from "module";

// sui-package-kit is CJS-only: its ESM build has unresolvable extensionless imports,
// and its CJS named exports cannot be statically detected from an ES module
// sui-package-kit is CJS-only: its ESM build has unresolvable extensionless imports,
// and its CJS named exports cannot be statically detected from an ES module
const require = createRequire(import.meta.url);
const { SuiAdvancePackagePublisher } = require("@scallop-io/sui-package-kit") as typeof import("@scallop-io/sui-package-kit");

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'testnet') as NetworkType;

// gRPC endpoint. `https://fullnode.apis.scallop.io` only serves JSON-RPC, so the
// default is the public fullnode; override with SUI_GRPC_URL to point at your own node.
// gRPC endpoint. `https://fullnode.apis.scallop.io` only serves JSON-RPC, so the default
// is the public fullnode; set SUI_GRPC_URL to point at a gRPC-capable node of your own.
export const grpcUrl = process.env.SUI_GRPC_URL || getFullnodeUrl(networkType);

export const suiKit = new SuiKit({ secretKey, networkType, fullnodeUrls: [grpcUrl] });

console.log(networkType);
console.log(suiKit.currentAddress);

export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });

/**
 * Replacement for the JSON-RPC `client.dryRunTransactionBlock`.
 *
 * `core.simulateTransaction` returns a `{ $kind, Transaction | FailedTransaction }`
 * union; this unwraps it so callers keep reading `.effects.status`, `.balanceChanges`
 * and `.events` the same way they did before.
 */
export const dryRunTx = async (transaction: string | Uint8Array | Transaction) => {
  const result = await suiKit.client.core.simulateTransaction({
    transaction: typeof transaction === 'string' ? fromBase64(transaction) : transaction,
    include: { effects: true, events: true, balanceChanges: true },
  });
  return result.Transaction ?? result.FailedTransaction;
};
