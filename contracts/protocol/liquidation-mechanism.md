# Liquidation Mechanism

## Overview

Scallop uses a **bad-debt-based liquidation model**. When a borrower's weighted debt value exceeds their collateral value (adjusted by liquidation factor), the position becomes liquidatable. A liquidator repays a portion of the borrower's debt and receives collateral in return, with a bonus as incentive. A small additional portion of collateral goes to the protocol as revenue.

## Key Concepts

### When Is a Position Liquidatable?

A position is liquidatable when:

```
weighted_debts_value > collaterals_value_for_liquidation
```

Where:
- `weighted_debts_value` = sum of each debt's USD value multiplied by its `borrow_weight`
- `collaterals_value_for_liquidation` = sum of each collateral's USD value multiplied by its `liquidation_factor`

### Bad Debt

The **bad debt** is the shortfall between weighted debts and discounted collateral:

```
bad_debt = weighted_debts_value - collaterals_value_for_liquidation
```

### Max Repay Amount

To prevent a single liquidation from stripping so much collateral that it creates **fresh bad debt** on the same obligation, the per-call repayment is capped at **20% of the total outstanding debt value across all debt types**, converted to the chosen `DebtType` token units:

```
max_repay_usd    = 20% * total_debts_value_usd   (sum of ALL debt types)
max_repay_amount = max_repay_usd / debt_price * debt_scale
                   (capped at the actual balance of the chosen DebtType)
```

**Exception — dust positions**: When the total USD value of all debts on the obligation is below **$10**, a full repay is allowed. This clears tiny positions where gas cost would otherwise exceed any partial-liquidation incentive:

```
if total_debts_value_usd < $10:
    max_repay_amount = total_debt_amount      (full repay)
```

> **Rationale for the 20% cap**: the old mechanism derived the cap from the bad-debt shortfall (`bad_debt / borrow_weight`). The problem is that after a liquidation, the collateral taken by the liquidator further reduces collateral value, which can generate new bad debt on the same obligation. Capping each call at 20% of the **total** portfolio debt (not per-type) makes liquidations gradual and prevents a liquidator from targeting multiple debt types in sequence to exceed the intended cap.

### Collateral Distribution

When the liquidator repays `R` tokens of debt:

1. **Liquidator receives**: collateral worth more than the repaid debt (bonus via `liq_discount`)
   ```
   liquidator_collateral = R * exchange_rate / (1 - liq_discount)
   ```

2. **Protocol receives**: a small percentage of collateral as revenue
   ```
   protocol_collateral = R * exchange_rate * liq_revenue_factor
   ```

Where:
- `exchange_rate = (collateral_scale / debt_scale) * (debt_price / collateral_price)` -- the market-price conversion from debt tokens to collateral tokens
- `liq_discount` -- the discount on collateral price for the liquidator (e.g., 5%)
- `liq_revenue_factor = liq_penalty - liq_discount` -- protocol's share (e.g., 8% - 5% = 3%)

### Worked Example

Given:
- Collateral Ca worth $12.50, `liquidation_factor = 0.8`
- Debt Da worth $6.00, `borrow_weight = 1`
- Debt Db worth $3.00, `borrow_weight = 2`
- `liq_discount = 5%`, `liq_penalty = 8%` (so `liq_revenue_factor = 3%`)

Computation:
```
weighted_debts  = 6 + 3 * 2 = $12.00
collateral_val  = 12.5 * 0.8 = $10.00
bad_debt        = 12 - 10    = $2.00    (position is liquidatable)

total_debts_value_usd = 6 + 3 = $9.00 < $10  →  dust: full repay allowed
```

Because total debt is below the $10 dust threshold, the liquidator may repay the full debt amount in one call.

---

**Non-dust example** (total debts > $10):
- Debt Da = 850 USDC at $1 (`borrow_weight = 1`), no other debts
- Collateral Ca worth $900 * 0.8 = $720 for liquidation
```
weighted_debts  = 850 * 1 = $850
collateral_val  = $720
bad_debt        = $130     (position is liquidatable)
total_debts_usd = $850 > $10  →  normal: 20% cap applies

max_repay_usd    = 20% * $850 = $170
max_repay (USDC) = $170 / $1  = 170 USDC
```

Liquidator repays 170 USDC:
```
liquidator gets = $170 / (1 - 0.05) / $price_collateral  (worth ~$178.95 of Ca)
protocol gets   = $170 * 0.03 / $price_collateral         (worth $5.10 of Ca)
```

After this liquidation, the obligation's health improves. If it is still unhealthy,
another liquidation call may repay another 20% of the remaining total debt value.

**Multi-debt example** (two debt types):
- Debt Da = 500 USDC at $1, Debt Db = 200 ETH at $3
- Collateral Ca worth $1,500 * 0.8 = $1,200 for liquidation
```
weighted_debts  = 500*1 + 200*3 = $1,100  (borrow_weight = 1 for both)
collateral_val  = $1,200  →  not yet liquidatable in this example
```

If the position were liquidatable:
```
total_debts_usd  = $500 + $600 = $1,100 > $10  →  normal: 20% cap applies

max_repay_usd    = 20% * $1,100 = $220
max_repay_Da     = $220 / $1    = 220 USDC   (≤ 500 USDC balance → 220 USDC)
max_repay_Db     = $220 / $3   ≈ 73.3 ETH   (≤ 200 ETH balance  → ~73 ETH)
```

The liquidator may repay at most $220 worth per call regardless of which debt type is chosen.

## Risk Model Parameters

Each collateral type has a `RiskModel` with these liquidation-related parameters:

| Parameter | Description | Max |
|---|---|---|
| `liquidation_factor` | Weight applied to collateral value for liquidation threshold | 95% |
| `liquidation_discount` | Bonus given to liquidators (lower collateral price) | 15% |
| `liquidation_penalty` | Total penalty on the borrower's collateral | 20% |
| `liquidation_revenue_factor` | Protocol's share (`penalty - discount`) | Derived |

Constraints enforced on-chain:
- `liquidation_factor > collateral_factor`
- `liquidation_penalty >= liquidation_discount`
- `liquidation_penalty + liquidation_factor < 1`

## Execution Flow

```
1. Liquidator calls liquidate<DebtType, CollateralType>(...)
2. Version, whitelist, and obligation lock checks
3. Accrue interests on market and obligation
4. (actual_repay, liq_amount, protocol_amount) =
       calculate_liquidation_amounts(...)              // in liquidation_evaluator
       - Computes max_repay (20% of total debt value across all types, or full if dust position)
       - Caps by available coins
       - Converts to collateral amounts, caps by available collateral
5. Withdraw collateral from obligation
6. Decrease obligation debt by actual_repay
7. Split collateral: liquidator share + protocol share
8. Market accounting: debt repay -> reserve, protocol collateral -> revenue
9. Emit LiquidateEventV2
10. Return (remaining_debt_coin, liquidator_collateral_coin)
```

## Key Differences from the Old Mechanism

| Aspect | Old Mechanism | New Mechanism |
|---|---|---|
| Max repay cap basis | Bad debt / borrow_weight | **20% of total debt value** across all types, converted to chosen type |
| Dust position handling | Same cap regardless of position size | Full repay allowed when total debts < $10 |
| Cascade risk | High — removing collateral can create new bad debt | Low — 20% cap keeps each step gradual |
| `borrow_weight` effect on cap | Reduces max repay for high-weight debts | No effect on repay cap (still affects liquidatability) |
| Protocol revenue source | Taken from the **debt repayment** (debt tokens) | Taken from the **collateral** (collateral tokens) |
| Debt reduction | Partial -- `repay - revenue` applied to debt | Full -- entire `actual_repay` reduces debt |
| Revenue type | `Balance<DebtType>` | `Balance<CollateralType>` |

---

## Developer Integration Guide

### Entry Points

**For frontends / PTBs** -- use the entry function:
```move
public entry fun liquidate_entry<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
)
```

**For composable calls** (from other Move modules or PTBs that need the return values):
```move
public fun liquidate<DebtType, CollateralType>(...): (Coin<DebtType>, Coin<CollateralType>)
```

Returns:
- `Coin<DebtType>` -- unused portion of the repay coin (refund to liquidator)
- `Coin<CollateralType>` -- liquidator's collateral reward (with bonus)

### Pre-Liquidation Queries

Before calling `liquidate`, the liquidator must first accrue interests so that debt and collateral values are up to date, then query the liquidation amounts:

**Step 1 — Accrue interests** (required, otherwise amounts will be stale):
```move
// Bring market and obligation interest state up to date
public fun accrue_interest_for_market_and_obligation(
    version: &Version,
    market: &mut Market,
    obligation: &mut Obligation,
    clock: &Clock,
)
```

**Step 2 — Query liquidation amounts**:
```move
// Compute actual repay, liquidator collateral, and protocol collateral in one call.
// Returns (actual_repay, liq_amount, protocol_amount).
// Aborts if the obligation is not liquidatable.
public fun calculate_liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    available_repay_amount: u64,
): (u64, u64, u64)
```

Lower-level helpers are also available if needed:
```move
// Get the max repay amount for a debt type (returns 0 if not liquidatable)
// Capped at 20% of total debt value across all types (converted to this type),
// or full debt if total debts value < $10.
public fun max_repay_amount<DebtType>(...): u64

// Convert a debt repay amount to collateral amounts
// Returns (liquidator_collateral, protocol_collateral)
public fun debt_to_collateral_amount<DebtType, CollateralType>(...): (u64, u64)
```

### Typical Liquidation Bot Flow

```
1. Monitor obligations for liquidatable positions
   - Check: weighted_debts_value > collaterals_value_for_liquidation

2. Accrue interests (required for accurate amounts):
   accrue_interest_for_market_and_obligation(version, market, obligation, clock)

3. Preview the liquidation:
   (actual_repay, liq_amount, protocol_amount) =
       calculate_liquidation_amounts<DebtType, CollateralType>(
           obligation, market, coin_decimals_registry, x_oracle, clock,
           available_repay_amount,
       )
   - If the obligation is not liquidatable, this aborts

4. Check profitability:
   - liq_amount (collateral received) should exceed actual_repay in value
   - The surplus is the liquidator's profit (liq_discount)

5. Execute:
   liquidate_entry<DebtType, CollateralType>(
       version, obligation, market, repay_coin,
       coin_decimals_registry, x_oracle, clock, ctx
   )

6. Repeat until the obligation is healthy.
   Each call repays up to 20% of the remaining total debt value (converted to the chosen type).
```

### Event Listening

Liquidation events are emitted as `LiquidateEventV2`:

```move
struct LiquidateEventV2 {
    liquidator: address,
    obligation: ID,
    debt_type: TypeName,
    collateral_type: TypeName,
    repay_on_behalf: u64,    // actual debt repaid (in debt token units)
    repay_revenue: u64,      // protocol's collateral revenue (in collateral token units)
    liq_amount: u64,         // liquidator's collateral reward (in collateral token units)
    collateral_price: FixedPoint32,
    debt_price: FixedPoint32,
    timestamp: u64,
}
```

Note: `repay_revenue` now represents the protocol's collateral share, not a debt-side fee.

### Modified Module Interfaces

The old `market::handle_liquidation` is preserved for backward compatibility. The new liquidation logic uses `handle_liquidation_v2`:

```move
// Old (preserved, do not use for new code)
public(friend) fun handle_liquidation<DebtType, CollateralType>(
    self: &mut Market,
    balance: Balance<DebtType>,          // debt repayment
    revenue_balance: Balance<DebtType>,  // protocol revenue (debt type)
    liquidate_amount: u64,
)

// New -- use this for the new liquidation mechanism
public(friend) fun handle_liquidation_v2<DebtType, CollateralType>(
    self: &mut Market,
    repay_balance: Balance<DebtType>,            // debt repayment (full amount)
    collateral_revenue: Balance<CollateralType>, // protocol revenue (collateral type)
    liquidate_amount: u64,
)
```

New friend modules should call `handle_liquidation_v2`. The key difference is the second parameter: `Balance<CollateralType>` (protocol revenue taken from collateral) instead of `Balance<DebtType>` (protocol revenue taken from debt repayment).
