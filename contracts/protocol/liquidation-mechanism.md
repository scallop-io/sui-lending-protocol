# nd Liquidation Mechanism

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

The liquidator can repay up to the bad debt value in any single debt type. The max repay amount in debt token units for a given `DebtType` is:

```
max_repay_value = bad_debt / borrow_weight          (in USD)
max_repay_amount = max_repay_value / debt_price      (in debt token units)
max_repay_amount = min(max_repay_amount, total_debt)  (capped by actual debt)
```

The `borrow_weight` adjusts for debts that carry higher risk (e.g., a debt with `borrow_weight = 2` only requires half as many tokens to cover the same bad debt value).

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
bad_debt        = 12 - 10    = $2.00
```

Liquidator chooses to repay Da:
```
max_repay_value = $2 / 1 = $2 worth of Da
liquidator gets = $2 / (1 - 0.05)  = ~$2.105 worth of Ca
protocol gets   = $2 * 0.03         = $0.06 worth of Ca
```

Or liquidator chooses to repay Db:
```
max_repay_value = $2 / 2 = $1 worth of Db
liquidator gets = $1 / (1 - 0.05)  = ~$1.053 worth of Ca
protocol gets   = $1 * 0.03         = $0.03 worth of Ca
```

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
       - Computes max_repay from bad debt, caps by available coins
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
| Max repay calculation | Based on collateral-debt exchange rate formula | Based on bad debt value / (debt_price * borrow_weight) |
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
    collateral_type: TypeName,
): (u64, u64, u64)
```

Lower-level helpers are also available if needed:
```move
// Get the max repay amount for a debt type (returns 0 if not liquidatable)
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
           available_repay_amount, collateral_type,
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
