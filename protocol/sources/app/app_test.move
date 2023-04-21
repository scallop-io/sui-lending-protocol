// TODO: remove this file when launch on mainnet
module protocol::app_test {
  use sui::tx_context::TxContext;
  use sui::math;
  use sui::transfer;
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol::mint;
  use protocol::obligation::{Obligation, ObligationKey};

  use test_coin::usdc::{Self, USDC};
  use test_coin::eth::{Self, ETH};
  use sui::clock::Clock;
  use protocol::deposit_collateral::deposit_collateral;
  use protocol::borrow::{borrow_entry};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use sui::coin::CoinMetadata;

  use oracle::price_feed::{Self, PriceFeedHolder, PriceFeedCap};

  public entry fun init_market(
    market: &mut Market,
    adminCap: &AdminCap,
    usdcTreasury: &mut usdc::Treasury,
    registry: &mut CoinDecimalsRegistry,
    coinMetaUsdc: &CoinMetadata<USDC>,
    coinMetaEth: &CoinMetadata<ETH>,
    priceFeedCap: &PriceFeedCap,
    priceFeeds: &mut PriceFeedHolder,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    init_risk_models(market, adminCap, ctx);
    init_intrest_models(market, adminCap, clock, ctx);
    init_limiters(market, adminCap, ctx);
    coin_decimals_registry::register_decimals<USDC>(registry, coinMetaUsdc);
    coin_decimals_registry::register_decimals<ETH>(registry, coinMetaEth);
    let usdcCoin = usdc::mint(usdcTreasury, ctx);
    init_price_feeds(priceFeedCap, priceFeeds);
    mint::mint_entry(market, usdcCoin, clock, ctx);
  }

  public entry fun simulate_user_actions(
    market: &mut Market,
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    ethTreasury: &mut eth::Treasury,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    price_feeds: &PriceFeedHolder,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let ethCoin = eth::mint(ethTreasury, ctx);
    deposit_collateral(obligation, market, ethCoin, ctx);
    let borrowAmount = math::pow(10, 10);
    borrow_entry<USDC>(obligation, obligationKey, market, coinDecimalsRegistry, borrowAmount, price_feeds, clock, ctx);
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

  fun init_price_feeds(
    priceFeedCap: &PriceFeedCap,
    priceFeeds: &mut PriceFeedHolder,
  ){
    price_feed::add_price_feed<USDC>(priceFeedCap, priceFeeds, 1, 1); // $1
    price_feed::add_price_feed<ETH>(priceFeedCap, priceFeeds, 2000, 1); // $2000
  }
}
