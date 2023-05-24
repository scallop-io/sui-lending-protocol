# Core of Scallop lending protocol on SUI network

## How to use

1. Install npm packages

```bash
pnpm install
```

2. Install SUI cli
See the official documentation: [How to install SUI cli](https://docs.sui.io/devnet/build/install)

3. Set the envs
  ```bash
  cp .env.example .env
  ```
  - `SECRET_KEY`: The secret key of the account that will be used to deploy the contracts, make sure the account has enough SUI to pay for the transaction fees
  - `SUI_NETWORK_TYPE`: The network type of the SUI network. It can be `devnet`, `testnet`, `mainnet` or `localnet`


## Move package structure
We use typescript to publish & interact with the contracts, and we make some improvements to the package structure to make it easier to use.

Let's take the `test_coin` package as an example:

![img.png](img.png)

- `sources` folder contains all the move contract code.

- `typescript` folder usually contains the typescript code that will be used to deploy & interact with the contract.

- `ids.${networkType}.json` contains the important object ids of the contracts for each network type.

- `index.ts` export the typescript code in the `typescript` folder.

- `Move.${networkType}.toml` is the toml file for each network type.

- `Move.toml` is the default toml file, it will be used if the `Move.${networkType}.toml` for the current network type is not found.

- `README.md` description of the package, explain the usage of the package.

## Publish move package
We use typescript to publish the move package.
The following steps will show you how to publish the `test_coin` package.

1. Make a new file `publish.ts` in the `typescript` folder for the package.:

```typescript
import * as path from "path"
import { suiKit, networkType } from "sui-elements"
import { publishPackageWithCache, writeAsJson } from "contract-deployment"

/**
 * 
 * If there's no `Move.${networkType}.toml` file in the package folder, it will
 * 1. publish the package with the default `Move.testnet.toml` file
 * 2. Write the object ids to the `ids.${networkType}.json` file
 * 3. And then, generate the `Move.${networkType}.toml` file based on the `Move.testnet.toml` file
 * 4. Make a backup of the `Move.testnet.toml` file as `Move.testnet.toml.bak`
 * 5. Replace the `Move.testnet.toml` file with the `Move.${networkType}.toml` file

 * Otherwise, it will:
 * 1. Replace the `Move.testnet.toml` file with the `Move.${networkType}.toml` file
 */
export const publishPackage = async () => {
  const pkgPath = path.join(__dirname, "../");
  // If the package has already been published, it will return undefined
  const res = await publishPackageWithCache(pkgPath, suiKit.getSigner(), networkType)
  if (!res) return;

  // Write your own `parseObjectIds` function to parse the necessary object ids from the publish result
  const parsedJson = parseObjectIds(res);

  writeAsJson(parsedJson, path.join(__dirname, `./ids.${networkType}.json`));
}
```
