module x_oracle::price_update_policy {

  use std::type_name::{Self, TypeName};
  use std::vector;
  use sui::vec_set::{Self, VecSet};
  use sui::object::{Self, UID, ID};
  use sui::tx_context::TxContext;
  use sui::table::{Self, Table};
  use sui::dynamic_field;

  use x_oracle::price_feed::PriceFeed;

  friend x_oracle::x_oracle;

  const REQUIRE_ALL_RULES_FOLLOWED: u64 = 721;
  const REQUST_NOT_FOR_THIS_POLICY: u64 = 722;
  const WRONG_POLICY_CAP: u64 = 723;

  struct PriceUpdateRequest<phantom T> {
    for: ID,
    receipts: VecSet<TypeName>,
    price_feeds: vector<PriceFeed>,
  }

  struct PriceUpdatePolicy has key, store {
    id: UID,
    rules: VecSet<TypeName>,
  }

  struct PriceUpdatePolicyCap has key, store {
    id: UID,
    for: ID,
  }

  struct PriceUpdatePolicyRulesKey has copy, drop, store {}

  public fun new(ctx: &mut TxContext): (PriceUpdatePolicy, PriceUpdatePolicyCap) {
    let policy = PriceUpdatePolicy {
      id: object::new(ctx),
      rules: vec_set::empty(),
    };
    let cap = PriceUpdatePolicyCap {
      id: object::new(ctx),
      for: object::id(&policy),
    };
    (policy, cap)
  }

  public fun new_request<T>(policy: &PriceUpdatePolicy): PriceUpdateRequest<T> {
    PriceUpdateRequest {
      for: object::id(policy),
      receipts: vec_set::empty(),
      price_feeds: vector::empty(),
    }
  }

  public(friend) fun init_rules_df_if_not_exist(_policy_cap: &PriceUpdatePolicyCap, policy: &mut PriceUpdatePolicy, ctx: &mut TxContext) {
    if(!dynamic_field::exists_<PriceUpdatePolicyRulesKey>(
        &policy.id,
        PriceUpdatePolicyRulesKey {},
    )) {
      dynamic_field::add<PriceUpdatePolicyRulesKey, Table<TypeName, VecSet<TypeName>>>(&mut policy.id, PriceUpdatePolicyRulesKey {}, table::new(ctx));
    }
  }

  public fun get_price_update_policy<CoinType>(policy: &PriceUpdatePolicy): VecSet<TypeName> {
    let rules_table = dynamic_field::borrow<PriceUpdatePolicyRulesKey, Table<TypeName, VecSet<TypeName>>>(
        &policy.id,
        PriceUpdatePolicyRulesKey {},
    );
    let coin_type = type_name::get<CoinType>();
    if (!table::contains(rules_table, coin_type)) {
      return vec_set::empty()
    };
    
    let rules = table::borrow(rules_table, coin_type);
    *rules
  }

  public(friend) fun add_rule_v2<CoinType, Rule>(
    policy: &mut PriceUpdatePolicy,
    cap: &PriceUpdatePolicyCap,
  ) {
    assert!(object::id(policy) == cap.for, WRONG_POLICY_CAP);
    let rules_table = dynamic_field::borrow_mut<PriceUpdatePolicyRulesKey, Table<TypeName, VecSet<TypeName>>>(
        &mut policy.id,
        PriceUpdatePolicyRulesKey {},
    );

    let coin_type = type_name::get<CoinType>();
    // add record if not exist
    if (!table::contains(rules_table, coin_type)) {
      table::add(rules_table, coin_type, vec_set::empty());
    };

    let rules = table::borrow_mut(rules_table, coin_type);
    vec_set::insert(rules, type_name::get<Rule>());
  }

  public fun add_rule<Rule>(
    policy: &mut PriceUpdatePolicy,
    cap: &PriceUpdatePolicyCap,
  ) {
    assert!(object::id(policy) == cap.for, WRONG_POLICY_CAP);
    vec_set::insert(&mut policy.rules, type_name::get<Rule>());
  }

  public(friend) fun remove_rule_v2<CoinType, Rule>(
    policy: &mut PriceUpdatePolicy,
    cap: &PriceUpdatePolicyCap,
  ) {
    assert!(object::id(policy) == cap.for, WRONG_POLICY_CAP);
    let rules_table = dynamic_field::borrow_mut<PriceUpdatePolicyRulesKey, Table<TypeName, VecSet<TypeName>>>(
        &mut policy.id,
        PriceUpdatePolicyRulesKey {},
    );

    let coin_type = type_name::get<CoinType>();
    // skip if not exist
    if (!table::contains(rules_table, coin_type)) {
      return
    };

    let rules = table::borrow_mut(rules_table, coin_type);
    vec_set::remove<TypeName>(rules, &type_name::get<Rule>());
  }  

  public fun remove_rule<Rule>(
    policy: &mut PriceUpdatePolicy,
    cap: &PriceUpdatePolicyCap,
  ) {
    assert!(object::id(policy) == cap.for, WRONG_POLICY_CAP);
    vec_set::remove<TypeName>(&mut policy.rules, &type_name::get<Rule>());
  }

  public fun add_price_feed<CoinType, Rule: drop>(
    _rule: Rule,
    request: &mut PriceUpdateRequest<CoinType>,
    feed: PriceFeed,
  ) {
    vec_set::insert(&mut request.receipts, type_name::get<Rule>());
    vector::push_back(&mut request.price_feeds, feed);
  }

  public fun confirm_request<CoinType>(request: PriceUpdateRequest<CoinType>, policy: &PriceUpdatePolicy): vector<PriceFeed> {
    let PriceUpdateRequest { receipts, for, price_feeds } = request;
    assert!(for == object::id(policy), REQUST_NOT_FOR_THIS_POLICY);

    let receipts = vec_set::into_keys(receipts);
    let completed = vector::length(&receipts);
    let rules = get_price_update_policy<CoinType>(policy);
    assert!(completed == vec_set::size(&rules), REQUIRE_ALL_RULES_FOLLOWED);
    let i = 0;
    while(i < completed) {
      let receipt = vector::pop_back(&mut receipts);
      assert!(vec_set::contains(&rules, &receipt), REQUIRE_ALL_RULES_FOLLOWED);
      i = i + 1;
    };
    price_feeds
  }
}
