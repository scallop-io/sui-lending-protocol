module mobius_core::liquidator {
  
  use mobius_core::position::{Self, Position};
  use sui::coin::{Self, Coin};
  use sui::tx_context::TxContext;
  use sui::object::{Self, UID};
  use sui::balance::Balance;
  use sui::transfer;
  use sui::tx_context;
  use mobius_core::bank::Bank;
  use mobius_core::bank;
  
  const ENotBeneficiary: u64 = 0;
  
  struct LiquidateVault<phantom LiquidCoinType, phantom AssetCoinType> has key {
    id: UID,
    liquidBalance: Balance<LiquidCoinType>,
    assetBalance: Balance<AssetCoinType>,
    beneficiary: address,
  }
  
  public entry fun liquidate<LiquidCoinType, AssetCoinType>(
    position: &mut Position,
    coin: Coin<LiquidCoinType>,
    ctx: &mut TxContext,
  ) {
    // remove debt from position
    position::remove_debt<LiquidCoinType>(position, coin::value(&coin));
    /// TODO: implement liquidate logic
    position::liquidate(position, ctx);
    // take asset from position
    let assetBalance = position::liquidate_collateral<AssetCoinType>(position, coin::value(&coin), ctx);
    // put the fund and asset into a vault
    let vault = LiquidateVault<LiquidCoinType, AssetCoinType> {
      id: object::new(ctx),
      liquidBalance: coin::into_balance(coin),
      assetBalance,
      beneficiary: tx_context::sender(ctx),
    };
    // make it a share object, so anyone later can trigger clearVault
    transfer::share_object(vault)
  }
  
  // After liquidation, any one can clear the vault
  public entry fun clearVault<LiquidCoinType, BankCoinType, AssetCoinType>(
    vault: LiquidateVault<LiquidCoinType, AssetCoinType>,
    bank: &mut Bank<LiquidCoinType, BankCoinType>,
    ctx: &mut TxContext,
  ) {
    // Unpack the vault
    let LiquidateVault { id, liquidBalance, assetBalance, beneficiary } = vault;
    object::delete(id);
    // Send the asset to beneficary
    transfer::transfer(
      coin::from_balance(assetBalance, ctx),
      beneficiary,
    );
    // Collect the fund to the bank
    bank::repay(bank, liquidBalance)
  }
}
