// TODO: remove this file when launch on mainnet
// @skip-auditing
module protocol::app_test {
  use sui::tx_context::{Self, TxContext};
  use sui::math;
  use sui::transfer;
  use sui::clock::Clock;
  use sui::coin::CoinMetadata;
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol::mint;

  use test_coin::usdc::{Self, USDC};
  use test_coin::eth::ETH;
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};

  use switchboard::switchboard_admin;
  use whitelist::whitelist;

  public entry fun init_market(
    market: &mut Market,
    adminCap: &AdminCap,
    usdcTreasury: &mut usdc::Treasury,
    registry: &mut CoinDecimalsRegistry,
    coinMetaUsdc: &CoinMetadata<USDC>,
    coinMetaEth: &CoinMetadata<ETH>,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    whitelist::add_whitelist_address(
      app::market_uid_mut(adminCap, market),
      tx_context::sender(ctx),
    );

    init_risk_models(market, adminCap, ctx);
    init_intrest_models(market, adminCap, clock, ctx);
    init_limiters(market, adminCap, ctx);
    coin_decimals_registry::register_decimals<USDC>(registry, coinMetaUsdc);
    coin_decimals_registry::register_decimals<ETH>(registry, coinMetaEth);
    let usdcCoin = usdc::mint(usdcTreasury, ctx);
    init_switchboard(clock, ctx);
    mint::mint_entry(market, usdcCoin, clock, ctx);
  }

  fun init_risk_models(
    market: &mut Market,
    adminCap: &AdminCap,
    ctx: &mut TxContext
  ) {
    // Init the risk model for ETH
    let collateralFactor = 70;
    let liquidationFactor = 80;
    let liquidationPanelty = 8;
    let liquidationDiscount = 5;
    let scale = 100;
    let maxCollateralAmount = math::pow(10, 9 + 7);
    let riskModelChange = app::create_risk_model_change<ETH>(
      adminCap,
      collateralFactor,
      liquidationFactor,
      liquidationPanelty,
      liquidationDiscount,
      scale,
      maxCollateralAmount,
      ctx,
    );
    app::add_risk_model<ETH>(market, adminCap, &mut riskModelChange, ctx);
    transfer::public_freeze_object(riskModelChange);
  }

  fun init_intrest_models(
    market: &mut Market,
    adminCap: &AdminCap,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    // Init the interest model for USDC
    let baseRatePerSec = 6341958;
    let lowSlope = 2 * math::pow(10, 16);
    let kink = 80 * math::pow(10, 14);
    let highSlope = 20 * math::pow(10, 16);
    let marketFactor = 2 * math::pow(10, 14);
    let scale = math::pow(10, 16);
    let minBorrowAmount = math::pow(10, 8);
    let borrow_weight = scale; // 1:1
    let interestModelChange = app::create_interest_model_change<USDC>(
      adminCap,
      baseRatePerSec,
      lowSlope,
      kink,
      highSlope,
      marketFactor,
      scale,
      minBorrowAmount,
      borrow_weight,
      ctx,
    );
    app::add_interest_model<USDC>(market, adminCap, &mut interestModelChange, clock, ctx);
    transfer::public_freeze_object(interestModelChange);
  }

  fun init_limiters(
    market: &mut Market,
    adminCap: &AdminCap,
    ctx: &mut TxContext
  ) {
    app::add_limiter<USDC>(
      adminCap,
      market,
      (math::pow(10, 6) * math::pow(10, 9)), // 1 million USDC
      60 * 60 * 24, // 24 hours
      60 * 30, // 30 minutes
      ctx
    );

    app::add_limiter<ETH>(
      adminCap,
      market,
      (math::pow(10, 3) * math::pow(10, 9)), // 1000 ETH
      60 * 60 * 24, // 24 hours
      60 * 30, // 30 minutes
      ctx
    );
  }

  fun init_switchboard(
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let (eth_price_aggr, eth_price_aggr_hp) =  switchboard_admin::new_aggregator(b"ETH/USD", ctx);
    let (usdc_price_aggr, usdc_price_aggr_hp) =  switchboard_admin::new_aggregator(b"USDC/USD", ctx);

    // Update the price of ETH to $2000
    switchboard_admin::update_price(&mut eth_price_aggr, 2000, 0, false, clock, ctx);
    // Update the price of USDC to $1
    switchboard_admin::update_price(&mut usdc_price_aggr, 1, 0, false, clock, ctx);

    switchboard_admin::share_aggregator(eth_price_aggr, eth_price_aggr_hp);
    switchboard_admin::share_aggregator(usdc_price_aggr, usdc_price_aggr_hp);
  }
}
