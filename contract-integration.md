# Guide on how to integrate with Scallop Lending Protocol 

## Introduction
The Scallop Lending Protocol is a decentralized lending protocol that allows users to lend and borrow crypto assets.
The protocol is built on the SUI blockchain and is completely open-source. The protocol is designed to be simple, efficient, and secure.
Moreover, the protocol is designed to be composable, meaning that other protocols can easily integrate with it.
The guide will walk you through the process of integrating with the Scallop Lending Protocol.

## Core concepts

### market
the market is the core of the protocol.

It is responsible for storing the state of the protocol, such as interest models, risk models, and other configurations.

It also stores the assets that are deposited by the users.

### sCoin
sCoin is the interest-bearing token of the protocol.

When a user deposits an asset into the protocol, the user receives sCoin in return.

The user can redeem the sCoin at any time to get back the asset and the interest that was earned.

### obligation
Obligation is used to create a credit line for the user, and track the debt of the user.

User keeps the obligation key, and the obligation key is used to access the obligation. User can have multiple obligations.

The user can deposit collaterals into the obligation and borrow assets from the protocol.

The user can withdraw collaterals from the obligation as long as the obligation is overcollateralized.

If the obligation is undercollateralized, anyone can liquidate the obligation, and get the collateral at a discount.

### xOracle
xOracle is used to get the price of the assets.

It retrieves the price from multiple oracle providers which prevents the oracle from being manipulated.

### Version
Version is used to enforce the upgrade of the protocol.

Each time the protocol is upgraded, the version is incremented.

### CoinDecimalsRegistry
CoinDecimalsRegistry is used to set/get the decimals of the assets.

Anyone can set the decimals of the assets by passing in the `CoinMetadata` of the asset.


## Import the Scallop Lending Protocol as a dependency
The core contract is named `ScallopProtocol`, and it is located in the [contracts/protocol](contracts/protocol) directory.

In your project, you can add the following lines to your `Move.toml` file to import the Scallop Lending Protocol as a dependency:
```toml

[dependencies.ScallopProtocol]
git = "https://github.com/scallop-io/sui-lending-protocol.git"
subdir = "contracts/protocol"
rev = "main"

```

## User interaction with the protocol
You can find all the modules that are responsible for user interaction in the [contracts/protocol/sources/user](contracts/protocol/sources/user) directory.

The include the following actions:
- `mint sCoin` - by minting sCoin, the user is depositing an asset into the protocol and receiving sCoin in return. The user starts earning interests by holding sCoin.
- `redeem sCoin` - by redeeming sCoin, the user is withdrawing an asset from the protocol and burning sCoin. The user get back the asset and the interest that was earned.
- `open obligation` - it creates a new obligation for the user. User can put collaterals into obligation and borrow assets from Scallop. Multiple obligations is possible for user.
- `deposit collateral` - it adds collateral to the obligation. The collateral can be used to borrow assets from Scallop.
- `withdraw collateral` - it withdraws collateral from the obligation.
- `borrow assets` - it borrows assets, and increase the debt of the obligation.
- `repay assets` - it repays assets, and decrease the debt of the obligation.
- `liquidation` - it liquidates the obligation if the obligation is undercollateralized.

### Mint sCoin
Module: [contracts/protocol/sources/user/mint.move](contracts/protocol/sources/user/mint.move)

Usage:
```move
module protocol::mint {
  
  // mint sCoin by supplying the underlying asset
  public fun mint<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<MarketCoin<T>> { }
  
}
```

### Redeem sCoin
Module: [contracts/protocol/sources/user/redeem.move](contracts/protocol/sources/user/redeem.move)

Usage:
```move
module protocol::redeem {
  
  // burn sCoin and get back the underlying asset
  public fun redeem<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<MarketCoin<T>>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> { }
  
}
```

### Open obligation
Module: [contracts/protocol/sources/user/open_obligation.move](contracts/protocol/sources/user/open_obligation.move)

Usage:
```move
module protocol::open_obligation {
  
  // open obligation
  // This creates a new obligation
  // the user keeps the obligation key.
  // the obligation key is used to access the obligation
  // ObligationHotPotato should be comsumed in the same transaction 
  public fun open_obligation(
    version: &Version,
    ctx: &mut TxContext,
  ): (Obligation, ObligationKey, ObligationHotPotato) { }
  
  // Consumes the obligation hot potato and shares the obligation
  public fun return_obligation(
    version: &Version,
    obligation: Obligation,
    obligation_hot_potato: ObligationHotPotato,
    ctx: &mut TxContext,
  ): () { }
  
}
```

### Deposit collateral
Module: [contracts/protocol/sources/user/deposit_collateral.move](contracts/protocol/sources/user/deposit_collateral.move)

Usage:
```move
module protocol::deposit_collateral {
  
  // deposit collateral to the obligation
  // user can deposit from any account, not just the obligation owner
  public fun deposit_collateral<T>(
    version: &Version,
    obligation: &mut Obligation,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ): () { }
  
}
```

### Withdraw collateral
Module: [contracts/protocol/sources/user/withdraw_collateral.move](contracts/protocol/sources/user/withdraw_collateral.move)

Usage:
```move
module protocol::withdraw_collateral {
  
  // withdraw collateral from the obligation
  // obligation key is required to withdraw collateral 
  // It also requires the oracle to be updated, interests will be accured for the obligation before withdrawal
  public fun withdraw_collateral<T>(
    version: &Version,
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    withdraw_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> { }
  
}
```

### Borrow assets
Module: [contracts/protocol/sources/user/borrow_assets.move](contracts/protocol/sources/user/borrow.move)

Usage:
```move
module protocol::borrow_assets {
  
  // borrow assets from the obligation
  // obligation key is required to borrow assets
  // It also requires the oracle to be updated, interests will be accured for the obligation before borrowing
  public fun borrow<T>(
    version: &Version,
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> { }
  
}
```

### Repay assets
Module: [contracts/protocol/sources/user/repay_assets.move](contracts/protocol/sources/user/repay.move)

Usage:
```move
module protocol::repay {
  
  // repay assets for the obligation
  // User can repay from any account, not just the obligation owner
  public entry fun repay<T>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    user_coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) { }
  
}
```

### Liquidation
Module: [contracts/protocol/sources/user/liquidate.move](contracts/protocol/sources/user/liquidate.move)

Usage:
```move
module protocol::liquidate {
  
  // liquidate the obligation
  // anyone can liquidate the obligation if the obligation is undercollateralized
  // It also requires the oracle to be updated, interests will be accured for the obligation before liquidation
  public fun liquidate<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) { }
  
}
```
