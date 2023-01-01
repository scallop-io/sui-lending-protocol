module protocol::bank {
  
  use std::vector;
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use math::mix;
  use math::fr::Fr;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::wit_table::{Self, WitTable};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::bank_vault::{Self, BankVault, BankCoin};
  
  const INITIAL_BANK_COIN_MINT_RATE: u64 = 1;
  
  struct BorrowIndexes has drop {}
  
  struct BorrowIndex has store {
    interestRate: Fr,
    mark: u64,
    lastUpdated: u64,
  }
  
  struct Bank has key {
    id: UID,
    borrowIndexes: WitTable<BorrowIndexes, TypeName, BorrowIndex>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    riskModels: AcTable<RiskModels, TypeName, RiskModel>,
    vault: BankVault
  }
  
  public fun new(ctx: &mut TxContext)
  : (Bank, AcTableCap<InterestModels>, AcTableCap<RiskModels>)
  {
    let (interestModels, interestModelsCap) = interest_model::new(ctx);
    let (riskModels, riskModelsCap) = risk_model::new(ctx);
    let bank = Bank {
      id: object::new(ctx),
      borrowIndexes: wit_table::new(BorrowIndexes{}, false, ctx),
      interestModels,
      riskModels,
      vault: bank_vault::new(ctx),
    };
    (bank, interestModelsCap, riskModelsCap)
  }
  
  public fun handle_borrow<T>(
    self: &mut Bank,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let borrowedBalance = bank_vault::withdraw_underlying_coin(&mut self.vault, borrowAmount);
    update_interest_rates(self);
    borrowedBalance
  }
  
  public fun handle_repay<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    update_interest_rates(self);
  }
  
  public fun handle_liquidation<T>(
    self: &mut Bank,
    balance: Balance<T>,
    reserveBalance: Balance<T>,
  ) {
    // We don't accrue interest here, because it has already been accrued in previous step for liquidation
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    bank_vault::deposit_underlying_coin(&mut self.vault, reserveBalance);
    update_interest_rates(self);
  }
  
  public fun handle_redeem<T>(
    self: &mut Bank,
    bankCoinBalance: Balance<BankCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddemBalance = bank_vault::redeem_underlying_coin(&mut self.vault, bankCoinBalance);
    update_interest_rates(self);
    reddemBalance
  }
  
  public fun handle_mint<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ): Balance<BankCoin<T>> {
    accrue_all_interests(self, now);
    let mintBalance = bank_vault::mint_bank_coin(&mut self.vault, balance);
    update_interest_rates(self);
    mintBalance
  }
  
  public fun compound_interests(
    self: &mut Bank,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    update_interest_rates(self);
  }
  
  public fun borrow_mark(self: &Bank, typeName: TypeName): u64 {
    let borrowIndex = wit_table::borrow(&self.borrowIndexes, typeName);
    borrowIndex.mark
  }
  
  public fun risk_model(self: &Bank, typeName: TypeName): &RiskModel {
    ac_table::borrow(&self.riskModels, typeName)
  }
  
  // accure interest for all banks
  public fun accrue_all_interests(self: &mut Bank, now: u64) {
    let assetTypes = bank_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let borrowIndex = wit_table::borrow_mut(BorrowIndexes {}, &mut self.borrowIndexes, type);
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let reserveFactor = interest_model::reserve_factor(interestModel);
      let debtIncreaseRate = mix::mul_ifr(now - borrowIndex.lastUpdated, borrowIndex.interestRate);
      bank_vault::increase_debt(&mut self.vault, type, debtIncreaseRate, reserveFactor);
      borrowIndex.mark = mix::mul_ifrT(
        borrowIndex.mark,
        mix::add_ifr(1, debtIncreaseRate)
      );
      borrowIndex.lastUpdated = now;
      i = i + 1;
    };
  }
  
  // accure interest for all banks
  public fun update_interest_rates(
    self: &mut Bank,
  ) {
    let assetTypes = bank_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let ultiRate = bank_vault::ulti_rate(&self.vault, type);
      let borrowIndex = wit_table::borrow_mut(BorrowIndexes {}, &mut self.borrowIndexes, type);
      let interestModel = ac_table::borrow(&self.interestModels, type);
      borrowIndex.interestRate = interest_model::calc_interest(interestModel, ultiRate);
      i = i + 1;
    };
  }
}
