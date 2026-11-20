// @scallop-io/sui-package-kit's `exports` map has no `types` condition, so bundler
// module resolution cannot find its declarations. They are re-pointed here rather than
// via tsconfig `paths`, which tsx would also apply to runtime resolution and would then
// try to `require()` a .d.ts file.
//
// Note: `export * from "<relative path>"` does not work inside `declare module` — ambient
// declarations resolve specifiers as module names, not file paths — so each name is
// re-exported through a type-position `import()`.
declare module "@scallop-io/sui-package-kit" {
  type Dist = typeof import("../node_modules/@scallop-io/sui-package-kit/dist/index");

  export type PackageBatch = import("../node_modules/@scallop-io/sui-package-kit/dist/lib/advance/index").PackageBatch;
  export type PublishResultParser = import("../node_modules/@scallop-io/sui-package-kit/dist/lib/advance/index").PublishResultParser;
  export const SuiAdvancePackagePublisher: Dist["SuiAdvancePackagePublisher"];
  export const SuiPackagePublisher: Dist["SuiPackagePublisher"];
}
