# Evaluator Layer

> `sources/evaluator/`

Pure computation modules — no state mutation. Used by both the user operation layer and off-chain bots (liquidation bots, health monitors, frontends).

---

## Modules

| File | Purpose |
|---|---|
| `borrow_withdraw_evaluator.move` | Max borrow / max collateral withdrawal amounts |
| `liquidation_evaluator.move` | Liquidation amounts: repay cap, liquidator share, protocol share |
| `collateral_value.move` | Aggregate collateral value in USD |
| `debt_value.move` | Aggregate debt value in USD |
| `price.move` | Oracle price fetching via XOracle |

---

## Health Model

A position has two thresholds:

```
healthy      ↔  weighted_debts_value  ≤  collaterals_value_for_borrow
liquidatable ↔  weighted_debts_value  >  collaterals_value_for_liquidation
```

The gap between the two thresholds (controlled by `collateral_factor` vs `liquidation_factor` in the risk model) is the safety buffer. See [Market Layer — RiskModel](../market/README.md#riskmodel--collateral-parameters).

---

## `collateral_value.move`

```
collaterals_value_usd_for_borrow(obligation, market, oracle, clock)
  = Σ( price(T) × collateral_amount(T) × collateral_factor(T) )

collaterals_value_usd_for_liquidation(obligation, market, oracle, clock)
  = Σ( price(T) × collateral_amount(T) × liquidation_factor(T) )
```

The borrow valuation applies the tighter `collateral_factor`; the liquidation valuation uses the slightly looser `liquidation_factor`. A position must deteriorate past the borrow threshold before being liquidatable.

---

## `debt_value.move`

```
debts_value_usd(obligation, market, oracle, clock)
  = Σ( price(T) × debt_amount(T) )

debts_value_usd_with_weight(obligation, market, oracle, clock)
  = Σ( price(T) × debt_amount(T) × borrow_weight(T) )
```

`borrow_weight` (1.0–5.0×) penalizes riskier assets when computing borrowing power. A debt in a high-weight asset uses proportionally more collateral.

---

## `borrow_withdraw_evaluator.move`

### Max borrow amount

```
available_borrow_usd
  = collaterals_value_for_borrow − debts_value_with_weight

max_borrow_amount<T>
  = available_borrow_usd / (price(T) × borrow_weight(T))
  (returns 0 if position is already at max leverage)
```

### Max collateral withdrawal

```
max_withdraw_amount<T>
  = ( collaterals_value_for_borrow − debts_value_with_weight )
    / ( price(T) × collateral_factor(T) )
  (returns 0 if position is unhealthy)
```

Both functions return `0` rather than aborting when the position has no headroom, allowing callers to handle the case gracefully.

---

## `liquidation_evaluator.move`

### Liquidatability check

```
liquidatable ↔ debts_value_with_weight > collaterals_value_for_liquidation
```

Aborts with an error if the obligation is not liquidatable.

### Max repay cap

```
if total_debts_usd < DUST_THRESHOLD ($10):
    max_repay = full debt amount          // dust position: one-shot clearance

else:
    max_repay_usd    = total_debts_usd / LIQUIDATION_CAP_DIVISOR (5)  // 20%
    max_repay_amount = max_repay_usd / debt_price × debt_scale
                       (capped at actual debt balance)
```

### Collateral conversion

```
exchange_rate = (collateral_scale / debt_scale) × (debt_price / collateral_price)

liquidator_amount = actual_repay × exchange_rate / (1 − liq_discount)
protocol_amount   = actual_repay × exchange_rate × liq_revenue_factor
```

If the obligation has insufficient collateral to cover the full liquidator share, amounts are scaled down proportionally.

### Full calculation

`calculate_liquidation_amounts<DebtType, CollateralType>` is the single call that returns `(actual_repay, liquidator_collateral, protocol_collateral)`. Used both by the on-chain `liquidate` function and off-chain bots for previewing.

---

## Off-chain Usage Pattern

```
// 1. Check if liquidatable
debts_w = debts_value_usd_with_weight(obligation, market, oracle, clock)
coll_l  = collaterals_value_usd_for_liquidation(obligation, market, oracle, clock)
if debts_w <= coll_l: skip

// 2. Preview amounts (accrue interest first for accuracy)
accrue_interest_for_market_and_obligation(version, market, obligation, clock)
(repay, liq, proto) = calculate_liquidation_amounts<DebtType, CollateralType>(
    obligation, market, decimals_registry, oracle, clock, available_repay
)

// 3. Check profitability
// liq collateral value > repay value  →  profit = liq_discount %

// 4. Execute
liquidate_entry<DebtType, CollateralType>(...)
```
