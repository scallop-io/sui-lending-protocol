/**
 * Shared helpers for building package upgrade transactions for the multisig.
 *
 * Used by upgrade-x.ts, upgrade-protocol.ts and upgrade-xoracle.ts.
 */
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { fileURLToPath } from "url";
import { SuiTxBlock } from "@scallop-io/sui-kit";
import { UpgradePolicy } from "@mysten/sui/transactions";
import { dryRunTx, networkType, packagePublisher } from "sui-elements";
import { buildMultiSigTx } from "./multi-sig";

// ESM does not provide CJS globals
const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const contractsRoot = path.join(__dirname, "../contracts");

export type BuiltPackage = { modules: string[]; dependencies: string[]; digest: number[] };

type LocalDependency = { name: string; local: string; dev: boolean };

/** Local dependencies declared in a Move.toml, in either `[dependencies.Name]` or inline-table form. */
function localDependencies(manifest: string): LocalDependency[] {
  const dependencies: LocalDependency[] = [];
  let section = "";
  for (const line of manifest.split(/\r?\n/)) {
    const header = line.match(/^\s*\[([^\]]+)\]\s*$/);
    if (header) {
      section = header[1].trim();
      continue;
    }
    const dev = section.startsWith("dev-");
    const local = line.match(/^\s*local\s*=\s*"([^"]+)"/);
    if (local && /^(dev-)?dependencies\./.test(section)) {
      dependencies.push({ name: section.split(".").slice(1).join("."), local: local[1], dev });
    }
    const inline = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*\{[^}]*\blocal\s*=\s*"([^"]+)"/);
    if (inline && /^(dev-)?dependencies$/.test(section)) {
      dependencies.push({ name: inline[1], local: inline[2], dev });
    }
  }
  return dependencies;
}

const publishedAt = (manifest: string) => manifest.match(/^published-at\s*=\s*"([^"]+)"/m)?.[1];

/** Copy a package's lock file and sources into the build tree, with the given Move.toml. */
function copyPackage(packagePath: string, target: string, manifest: string) {
  fs.mkdirSync(target, { recursive: true });
  fs.writeFileSync(path.join(target, "Move.toml"), manifest);
  for (const entry of ["Move.lock", "sources"]) {
    const source = path.join(packagePath, entry);
    if (fs.existsSync(source)) fs.cpSync(source, path.join(target, entry), { recursive: true });
  }
}

/**
 * Compile a package under contracts/ the way an upgrade needs it. The build runs on a temporary
 * copy, so the repo's files are not touched:
 *   - the package's own address (`addressName`) is set to 0x0 and its `published-at` is removed,
 *     because upgraded modules must be compiled with address 0x0;
 *   - every local dependency uses its Move.<network>.toml when it has one, so it links to its
 *     published package. A dependency that isn't published makes the build fail instead of being
 *     bundled into the upgrade.
 * Prints the `published-at` of every local dependency, so you can check what the upgrade links to.
 */
export function buildForUpgrade(packagePath: string, addressName: string): BuiltPackage {
  const buildRoot = fs.mkdtempSync(path.join(os.tmpdir(), "package-upgrade-"));
  try {
    const addressLine = new RegExp(`^(${addressName}\\s*=\\s*)"0x[0-9a-fA-F]+"`, "m");
    const manifest = fs.readFileSync(path.join(packagePath, "Move.toml"), "utf8")
      .replace(/^published-at\s*=.*\r?\n/m, "")
      .replace(addressLine, '$1"0x0"');
    if (!new RegExp(`^${addressName}\\s*=\\s*"0x0"`, "m").test(manifest)) {
      throw new Error(`Could not set the ${addressName} address to 0x0 in the build copy of Move.toml`);
    }

    const toBuildPath = (packageDir: string) => {
      const relative = path.relative(contractsRoot, packageDir);
      if (relative.startsWith("..") || path.isAbsolute(relative)) {
        throw new Error(`Package is outside contracts/: ${packageDir}`);
      }
      return path.join(buildRoot, relative);
    };

    copyPackage(packagePath, toBuildPath(packagePath), manifest);

    const queue = localDependencies(manifest).map((dependency) => ({ ...dependency, from: packagePath }));
    const copied = new Set<string>();
    console.log("Local dependencies (published-at the upgrade links to):");
    while (queue.length > 0) {
      const dependency = queue.shift()!;
      const dependencyPath = path.resolve(dependency.from, dependency.local);
      if (copied.has(dependencyPath)) continue;
      copied.add(dependencyPath);

      const networkManifestPath = path.join(dependencyPath, `Move.${networkType}.toml`);
      const dependencyManifest = fs.readFileSync(
        fs.existsSync(networkManifestPath) ? networkManifestPath : path.join(dependencyPath, "Move.toml"),
        "utf8",
      );
      if (!dependency.dev) {
        console.log(`  ${dependency.name}: ${publishedAt(dependencyManifest) ?? "NOT PUBLISHED"}`);
      }
      copyPackage(dependencyPath, toBuildPath(dependencyPath), dependencyManifest);
      queue.push(...localDependencies(dependencyManifest).map((next) => ({ ...next, from: dependencyPath })));
    }

    return packagePublisher.packagePublisher.buildPackage(toBuildPath(packagePath), {
      withUnpublishedDependencies: false,
    });
  } finally {
    fs.rmSync(buildRoot, { recursive: true, force: true });
  }
}

/**
 * Build the upgrade transaction (compatible policy) with the multisig as sender, dry-run it, and
 * return the bytes to sign. The dry run also prints the ID the upgraded package will get; that ID
 * holds only for these exact bytes, so it changes if the transaction is built again.
 */
export async function createMultiSigUpgradeTx(
  built: BuiltPackage,
  oldPackageId: string,
  upgradeCapId: string,
): Promise<string> {
  const tx = new SuiTxBlock();
  const ticket = tx.moveCall("0x2::package::authorize_upgrade", [
    tx.object(upgradeCapId),
    tx.pure.u8(UpgradePolicy.COMPATIBLE),
    tx.pure.vector("u8", built.digest),
  ]);
  const receipt = tx.upgrade({
    modules: built.modules,
    dependencies: built.dependencies,
    package: oldPackageId,
    ticket,
  });
  tx.moveCall("0x2::package::commit_upgrade", [tx.object(upgradeCapId), receipt]);

  const txBytes = await buildMultiSigTx(tx);

  const result: any = await dryRunTx(txBytes);
  console.log("Dry run status:", JSON.stringify(result?.status));
  const upgradedPackage = result?.effects?.changedObjects?.find(
    (object: any) => object.outputState === "PackageWrite" && object.idOperation === "Created",
  );
  if (upgradedPackage) console.log(`Upgraded package ID: ${upgradedPackage.objectId}`);

  return txBytes;
}
