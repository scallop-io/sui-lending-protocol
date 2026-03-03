# Market Layer

> `sources/market/`

The market layer is the core state machine of the protocol. It owns all asset-level accounting and exposes `pub(friend)` mutation APIs consumed exclusively by the [user operation layer](../user/README.md).

---

## Modules

| File | Purpose |
|---|---|
| `market.move` | Central shared object; orchestrates all sub-modules |
| `reserve.move` | Asset custody: underlying tokens, sCoin supply, balance sheets |
| `borrow_dynamics.move` | Per-asset borrow index and interest rate state |
| `interest_model.move` | Piecewise-linear interest rate curves |
| `risk_model.move` | Collateral factors and liquidation parameters |
| `collateral_stats.move` | Global collateral amount per asset |
| `limiter.move` | Rolling-window outflow rate limiter |
| `apm.move` | 24-hour price history for manipulation detection |
| `asset_active_state.move` | Supply / collateral / borrow activation flags |
| `market_dynamic_keys.move` | Dynamic field key types (supply limit, borrow limit, fees…) |
| `incentive_rewards.move` | Deprecated; retained for struct compatibility |

---

## `Market` — Central Object

```move
struct Market {
  id: UID,
  borrow_dynamics:     WitTable<BorrowDynamics,    TypeName, BorrowDynamic>,
  collateral_stats:    WitTable<CollateralStats,   TypeName, CollateralStat>,
  interest_models:     AcTable<InterestModels,     TypeName, InterestModel>,
  risk_models:         AcTable<RiskModels,         TypeName, RiskModel>,
  limiters:            WitTable<Limiters,          TypeName, Limiter>,
  reward_factors:      WitTable<RewardFactors,     TypeName, RewardFactor>,  // deprecated
  asset_active_states: AssetActiveStates,
  vault:               Reserve,
}
```

All tables are keyed by `TypeName` (the fully qualified coin type). Mutations to `WitTable` require a one-time witness token; mutations to `AcTable` require the corresponding admin capability. This prevents any external code from bypassing access control even with a shared reference to `Market`.

---

## `Reserve` — Asset Custody

`Reserve` is the only place where actual token balances are held.

```move
struct Reserve {
  id: UID,
  market_coin_supplies: SupplyBag,    // sCoin (MarketCoin<T>) supplies
  underlying_balances:  BalanceBag,   // actual token balances
  balance_sheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
  flash_loan_fees: WitTable<FlashLoanFees, TypeName, u64>,
}

struct BalanceSheet {
  cash:               u64,   // available liquidity
  debt:               u64,   // total outstanding borrow principal + accrued interest
  revenue:            u64,   // protocol's share of interest (never mixed with cash)
  market_coin_supply: u64,   // total minted sCoin
}
```

**sCoin exchange rate:**

```
price = (cash + debt - revenue) / market_coin_supply
```

`revenue` is subtracted from the numerator because it is earmarked for the protocol and cannot be redeemed by sCoin holders. As interest accrues, `debt` rises → price rises → all sCoin holders earn yield automatically.

**Invariant:** `cash >= revenue` is asserted before every withdrawal to guarantee solvent redemptions.

---

## `BorrowDynamics` — Interest Index

Interest is compounded via a global borrow index per asset. This avoids iterating over all positions on every block.

```move
struct BorrowDynamic {
  interest_rate:       FixedPoint32,  // current per-second borrow rate
  interest_rate_scale: u64,
  borrow_index:        u64,           // starts at 1e9, grows monotonically
  last_updated:        u64,           // unix timestamp of last accrual
}
```

**Index update (called on every market interaction):**

```
new_index = old_index × (1 + interest_rate × Δt / scale)
```

Each `Obligation` stores a snapshot of the index at borrow time. Actual debt is recovered lazily:

```
actual_debt = stored_amount × (current_index / snapshot_index)
```

---

## `InterestModel` — Rate Curves

A 3-segment piecewise-linear borrow rate curve per asset:

```
utilization = debt / (cash + debt - revenue)

rate(u):
  [0,        mid_kink]  → linear: base_rate → rate_at_mid_kink
  [mid_kink, high_kink] → linear: rate_at_mid_kink → rate_at_high_kink
  [high_kink, 1]        → linear: rate_at_high_kink → max_borrow_rate
```

The two-kink design allows cheap rates at low utilization, sharply rising rates near full utilization to attract liquidity back.

**Constraints enforced on-chain:**

| Parameter | Constraint |
|---|---|
| `max_borrow_rate` | ≤ 1000% |
| `borrow_weight` | 100% – 500% |
| `revenue_factor` | ≤ 100% |

Changes to interest models require a minimum **7-epoch governance delay**. See [governance](../app/README.md#governance-delays).

---

## `RiskModel` — Collateral Parameters

```move
struct RiskModel {
  collateral_factor:          FixedPoint32,  // borrowing power (max 95%)
  liquidation_factor:         FixedPoint32,  // liquidation threshold (max 95%)
  liquidation_penalty:        FixedPoint32,  // total penalty charged to borrower (max 20%)
  liquidation_discount:       FixedPoint32,  // liquidator's bonus (max 15%)
  liquidation_revenue_factor: FixedPoint32,  // = penalty − discount (protocol's cut)
  max_collateral_amount:      u64,           // system-wide deposit cap
}
```

**Required relationships:**

```
collateral_factor  <  liquidation_factor
liquidation_discount ≤ liquidation_penalty
liquidation_factor   +  liquidation_penalty  <  100%
```

The gap between `collateral_factor` and `liquidation_factor` is the **safety buffer** — a position must deteriorate significantly before it becomes liquidatable.

---

## `Limiter` — Outflow Rate Limiter

Protects against coordinated bank runs. Each asset has a rolling outflow limit tracked in fixed-width time segments.

```move
struct Limiter {
  outflow_limit:            u64,   // max net outflow per cycle
  outflow_cycle_duration:   u64,   // e.g., 86400 s (24 h)
  outflow_segment_duration: u64,   // e.g., 1800 s (30 min)
}
```

Active segments within the current cycle are summed. Repayments reduce the current segment, effectively giving credit for inflows. Exceeding the limit blocks further borrows and redeems for that asset until the cycle rolls forward.

See [Safety Mechanisms](../safety.md#rate-limiter) for details.

---

## `APM` — Advanced Price Monitor

Tracks hourly minimum prices over a 24-hour window (24 buckets). If the current oracle price is more than `threshold` times above the 24-hour minimum, the operation is aborted.

```move
struct MinPriceHistory {
  prices:       vector<FixedPoint32>,  // 24 hourly buckets
  bucket_index: u64,
  updated_at:   u64,
}
```

Only upward spikes are flagged (downward moves are genuine market events unfavorable to attackers). See [Safety Mechanisms](../safety.md#advanced-price-monitor-apm).
