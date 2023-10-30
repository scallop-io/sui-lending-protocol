// refactor obligation to better handle operations
module protocol::obligation {
  
  use std::type_name::{Self, TypeName};
  use std::option::{Self, Option};
  use std::vector;
  use std::fixed_point32;
  use sui::object::{Self, UID, ID};
  use sui::balance::{Self, Balance};
  use sui::event::emit;
  use sui::tx_context;

  use x::balance_bag::{Self, BalanceBag};
  use x::ownership::{Self, Ownership};
  use x::wit_table::{Self, WitTable};
  use x::witness::Witness;

  use protocol::obligation_debts::{Self, ObligationDebts, Debt};
  use protocol::obligation_collaterals::{Self, ObligationCollaterals, Collateral};
  use protocol::market::{Self, Market};
  use protocol::incentive_rewards;
  use protocol::obligation_access::{Self, ObligationAccessStore};
  use protocol::error;

  friend protocol::repay;
  friend protocol::borrow;
  friend protocol::withdraw_collateral;
  friend protocol::deposit_collateral;
  friend protocol::liquidate;
  friend protocol::open_obligation;
  friend protocol::accrue_interest;
  friend protocol::lock_obligation;
  
  struct Obligation has key, store {
    id: UID,
    balances: BalanceBag,
    debts: WitTable<ObligationDebts, TypeName, Debt>,
    collaterals: WitTable<ObligationCollaterals, TypeName, Collateral>,
    rewards_point: u64,
    lock_key: Option<TypeName>,
    borrow_locked: bool,
    repay_locked: bool,
    deposit_collateral_locked: bool,
    withdraw_collateral_locked: bool,
    liquidate_locked: bool, // Almost impossible to be true, but we still want the possibility in future
  }
  
  struct ObligationOwnership has drop {}
  
  struct ObligationKey has key, store {
    id: UID,
    ownership: Ownership<ObligationOwnership>
  }

  /// ==== Events ====

  struct ObligationRewardsPointRedeemed has copy, drop {
    obligation: ID,
    witness: TypeName,
    amount: u64,
  }

  struct ObligationLocked has copy, drop {
    obligation: ID,
    witness: TypeName,
    borrow_locked: bool,
    repay_locked: bool,
    deposit_collateral_locked: bool,
    withdraw_collateral_locked: bool,
    liquidate_locked: bool,
  }

  struct ObligationUnlocked has copy, drop {
    obligation: ID,
    witness: TypeName,
  }

  /// ==== Leave room for future extension ====

  public fun obligation_key_uid(key: &ObligationKey, _: Witness<ObligationKey>): &UID {
    &key.id
  }
  /// Get mut UID for obligation key with delegted witness
  public fun obligation_key_uid_mut_delegated(key: &mut ObligationKey, _: Witness<ObligationKey>): &mut UID {
    &mut key.id
  }

  public fun obligation_uid(obligation: &Obligation, _: Witness<Obligation>): &UID {
    &obligation.id
  }
  /// Get mut UID for obligation with delegated witness
  public fun obligation_uid_mut_delegated(obligation: &mut Obligation, _: Witness<Obligation>): &mut UID {
    &mut obligation.id
  }

  public(friend) fun new(ctx: &mut tx_context::TxContext): (Obligation, ObligationKey) {
    let obligation = Obligation {
      id: object::new(ctx),
      balances: balance_bag::new(ctx),
      debts: obligation_debts::new(ctx),
      collaterals: obligation_collaterals::new(ctx),
      rewards_point: 0,
      lock_key: option::none(),
      borrow_locked: false,
      repay_locked: false,
      deposit_collateral_locked: false,
      withdraw_collateral_locked: false,
      liquidate_locked: false,
    };
    let obligation_ownership = ownership::create_ownership(
      ObligationOwnership{},
      object::id(&obligation),
      ctx
    );
    let obligation_key = ObligationKey {
      id: object::new(ctx),
      ownership: obligation_ownership,
    };
    (obligation, obligation_key)
  }
  
  public fun assert_key_match(obligation: &Obligation, key: &ObligationKey) {
    ownership::assert_owner(&key.ownership, obligation)
  }
  
  public fun is_key_match(obligation: &Obligation, key: &ObligationKey): bool {
    ownership::is_owner(&key.ownership, obligation)
  }
  
  public(friend) fun accrue_interests_and_rewards(
    obligation: &mut Obligation,
    market: &Market,
  ) {
    let debt_types = debt_types(obligation);
    let (i, n) = (0, vector::length(&debt_types));
    while (i < n) {
      let type = *vector::borrow(&debt_types, i);
      let new_borrow_index = market::borrow_index(market, type);
      // accrue interest first, and then accrue the incentive_rewards to get the latest borrow amount
      let accrued_interest = obligation_debts::accrue_interest(&mut obligation.debts, type, new_borrow_index);
      
      let reward_factor = incentive_rewards::reward_factor(market::reward_factor(market, type));
      let accrued_rewards_point = fixed_point32::multiply_u64(accrued_interest, reward_factor);
      obligation.rewards_point = obligation.rewards_point + accrued_rewards_point;

      i = i + 1;
    };
  }
  
  public(friend) fun withdraw_collateral<T>(
    self: &mut Obligation,
    amount: u64,
  ): Balance<T> {
    let type_name = type_name::get<T>();
    // reduce collateral amount
    obligation_collaterals::decrease(&mut self.collaterals, type_name, amount);
    // return the collateral balance
    balance_bag::split(&mut self.balances, amount)
  }
  
  public(friend) fun deposit_collateral<T>(
    self: &mut Obligation,
    balance: Balance<T>,
  ) {
    // increase collateral amount
    let type_name = type_name::get<T>();
    obligation_collaterals::increase(&mut self.collaterals, type_name, balance::value(&balance));
    // put the collateral balance
    if (balance_bag::contains<T>(&self.balances) == false) {
      balance_bag::init_balance<T>(&mut self.balances);
    };
    balance_bag::join(&mut self.balances, balance);
  }
  
  public(friend) fun init_debt(
    self: &mut Obligation,
    market: &Market,
    type_name: TypeName,
  ) {
    let borrow_index = market::borrow_index(market, type_name);
    obligation_debts::init_debt(&mut self.debts, type_name, borrow_index);
  }
  
  public(friend) fun increase_debt(
    self: &mut Obligation,
    type_name: TypeName,
    amount: u64,
  ) {
    obligation_debts::increase(&mut self.debts, type_name, amount);
  }
  
  public(friend) fun decrease_debt(
    self: &mut Obligation,
    type_name: TypeName,
    amount: u64,
  ) {
    obligation_debts::decrease(&mut self.debts, type_name, amount);
  }

  public fun debt(self: &Obligation, type_name: TypeName): (u64, u64) {
    obligation_debts::debt(&self.debts, type_name)
  }
  
  public fun collateral(self: &Obligation, type_name: TypeName): u64 {
    obligation_collaterals::collateral(&self.collaterals, type_name)
  }
  
  // return the debt types
  public fun debt_types(self: &Obligation): vector<TypeName> {
    wit_table::keys(&self.debts)
  }
  
  // return the collateral types
  public fun collateral_types(self: &Obligation): vector<TypeName> {
    wit_table::keys(&self.collaterals)
  }

  /// ====== Readonly data ======
  public fun balance_bag(self: &Obligation): &BalanceBag {
    &self.balances
  }
  
  public fun debts(self: &Obligation): &WitTable<ObligationDebts, TypeName, Debt> {
    &self.debts
  }
  
  public fun collaterals(self: &Obligation): &WitTable<ObligationCollaterals, TypeName, Collateral> {
    &self.collaterals
  }

  public fun rewards_point(self: &Obligation): u64 { self.rewards_point }
  public fun borrow_locked(self: &Obligation): bool { self.borrow_locked }
  public fun repay_locked(self: &Obligation): bool { self.repay_locked }
  public fun withdraw_collateral_locked(self: &Obligation): bool { self.withdraw_collateral_locked }
  public fun deposit_collateral_locked(self: &Obligation): bool { self.deposit_collateral_locked }
  public fun liquidate_locked(self: &Obligation): bool { self.liquidate_locked }
  public fun lock_key(self: &Obligation): Option<TypeName> { self.lock_key }

  /// ==== obligation lock management =====

  /// lock the obligation with a key
  /// The key must be defined in the obligation_access_store
  /// only the obligation owner can lock the obligation
  public fun lock<T: drop>(
    self: &mut Obligation,
    obligation_key: &ObligationKey,
    obligation_access_store: &ObligationAccessStore,
    lock_borrow: bool,
    lock_repay: bool,
    lock_deposit_collateral: bool,
    lock_withdraw_collateral: bool,
    lock_liquidate: bool,
    key: T
  ) {
    assert_key_match(self, obligation_key);
    
    set_lock<T>(
      self,
      obligation_access_store,
      lock_borrow,
      lock_repay,
      lock_deposit_collateral,
      lock_withdraw_collateral,
      lock_liquidate,
      key
    );

    emit(ObligationLocked {
      obligation: object::id(self),
      witness: type_name::get<T>(),
      borrow_locked: self.borrow_locked,
      repay_locked: self.repay_locked,
      withdraw_collateral_locked: self.withdraw_collateral_locked,
      deposit_collateral_locked: self.deposit_collateral_locked,
      liquidate_locked: self.liquidate_locked,
    });
  }

  /// unlock the obligation with a key
  /// The key must be the same as the key used to lock the obligation
  /// only the obligation owner can unlock the obligation
  public fun unlock<T: drop>(
    self: &mut Obligation,
    obligation_key: &ObligationKey,
    key: T
  ) {
    assert_key_match(self, obligation_key);
    
    set_unlock(self, key);

    emit(ObligationUnlocked {
      obligation: object::id(self),
      witness: type_name::get<T>(),
    });
  }

  public(friend) fun set_lock<T: drop>(
    self: &mut Obligation,
    obligation_access_store: &ObligationAccessStore,
    lock_borrow: bool,
    lock_repay: bool,
    lock_deposit_collateral: bool,
    lock_withdraw_collateral: bool,
    lock_liquidate: bool,
    key: T
  ) {
    assert!(
      option::is_none(&self.lock_key),
      error::obligation_already_locked()
    );

    obligation_access::assert_lock_key_in_store(obligation_access_store, key);

    self.lock_key = option::some(type_name::get<T>());
    self.borrow_locked = lock_borrow;
    self.repay_locked = lock_repay;
    self.withdraw_collateral_locked = lock_withdraw_collateral;
    self.deposit_collateral_locked = lock_deposit_collateral;
    self.liquidate_locked = lock_liquidate;
  }

  public(friend) fun set_unlock<T: drop>(
    self: &mut Obligation,
    _: T
  ) {
    assert!(
      *option::borrow(&self.lock_key) == type_name::get<T>(),
      error::obligation_unlock_with_wrong_key()
    );

    self.lock_key = option::none();
    self.borrow_locked = false;
    self.repay_locked = false;
    self.withdraw_collateral_locked = false;
    self.deposit_collateral_locked = false;
    self.liquidate_locked = false;
  }

  /// ====== obligation rewards point access management

  /// Redeem the rewards point with a key
  /// The key must be defined in the obligation_access_store
  /// only the obligation owner can redeem the rewards point
  public fun redeem_rewards_point<T: drop>(
    self: &mut Obligation,
    obligation_key: &ObligationKey,
    obligation_access_store: &ObligationAccessStore,
    key: T,
    amount: u64
  ) {
    assert_key_match(self, obligation_key);
    obligation_access::assert_reward_key_in_store(obligation_access_store, key);
    self.rewards_point = self.rewards_point - amount;

    emit(ObligationRewardsPointRedeemed {
      obligation: object::id(self),
      witness: type_name::get<T>(),
      amount,
    });
  }

  #[test_only]
  public fun new_obligation_test(ctx: &mut tx_context::TxContext): (Obligation, ObligationKey) {
    new(ctx)
  }

  #[test_only]
  public fun add_debt_test(
    self: &mut Obligation,
    type_name: TypeName,
    amount: u64,
  ) {
    obligation_debts::init_debt(&mut self.debts, type_name, sui::math::pow(10, 9));
    increase_debt(self, type_name, amount);
  }
}
