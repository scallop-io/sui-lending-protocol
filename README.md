# Core of Scallop lending protocol on SUI network

## How to use

1. Install the package

```bash
npm install
```

2. Install SUI cli
See the official documentation: [How to install SUI cli](https://docs.sui.io/devnet/build/install)

3. Set the envs
  ```bash
  cp .env.example .env
  ```
  - `SECRET_KEY`: The secret key of the account that will be used to deploy the contracts, make sure the account has enough SUI to pay for the transaction fees
  - `SUI_NETWORK_TYPE`: The network type of the SUI network. It can be `devnet`, `testnet`, `mainnet` or `localhost`

4. Deploy the contracts & prepare test data
  ```bash
  npm run setup
  ```
This will deploy the contracts and prepare test data for the contracts.
Also, it will create a file named `object-ids.json` which contains all the necessary object ids for the contracts.
