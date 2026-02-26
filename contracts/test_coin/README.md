# Test Coin Package

### Description

This package contains several modules that create test coins for testing purposes.
Currently, it will create the following coin types:
- btc::BTC
- eth::ETH
- usdc::USDC
- usdt::USDT

It also contains typescript utilities for publishing and minting test coins.

### Publish
To publish test coins, run the following command from the project root:
```bash
pnpm run publish-testcoin
```

### Mint
After publishing, you can use the typescript utilities in the `typescript` folder to mint test coins for testing purposes.