module test_coin::package {

  use sui::tx_context::TxContext;
  use sui::package;

  struct PACKAGE has drop {}

  fun init(otw: PACKAGE, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
  }
}
