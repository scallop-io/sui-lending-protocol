# Economic Model

---

## Supply-Side Yield (sCoin)

When a user supplies asset `T`, they receive `MarketCoin<T>` (sCoin) in proportion to the current exchange rate:

```
sCoin_minted = deposit_amount / price
price        = (cash + debt - revenue) / market_coin_supply
```

Over time, as borrowers pay interest, `debt` in the `BalanceSheet` rises (accrual) and then converts to `cash` (on repayment). Because `revenue` (protocol cut) is subtracted, sCoin holders receive the net yield:

```
supplier_yield = borrow_rate × (1 − revenue_factor) × utilization
```

sCoin price is monotonically non-decreasing. Redemption always returns more underlying than was deposited (assuming any time has passed with non-zero utilization).

---

## Borrow-Side Cost

Borrowers pay two costs:

### 1. One-Time Borrow Fee

Charged at the moment of borrowing, before the loan is disbursed. Configurable per asset. Supports referral discounts.

```
net_fee = borrow_fee × (1 − referral_discount)
```

Accumulated fees are withdrawn by the admin via `take_borrow_fee<T>`.

### 2. Ongoing Interest

Accrued per second via the global borrow index (see [BorrowDynamics](market/README.md#borrowdynamics--interest-index)).

```
effective_annual_rate = interest_model.calc_interest(utilization)
```

Interest rate is a function of **utilization** (`debt / (cash + debt - revenue)`). Higher utilization → higher rates, incentivizing new supply and discouraging new borrows, balancing the pool.

---

## Protocol Revenue

The protocol earns from two sources:

| Source | Mechanism |
|---|---|
| Interest revenue | `revenue_factor` fraction of all accrued interest, held in `BalanceSheet.revenue` |
| Borrow fees | One-time fee on each borrow, accumulated separately |
| Flash loan fees | Fee per flash loan, added directly to `revenue` |
| Liquidation revenue | `liq_revenue_factor` share of liquidated collateral |

All revenue is withdrawable by the admin via `take_revenue<T>` and `take_borrow_fee<T>`.

---

## Liquidation Economics

When a position becomes liquidatable, a liquidator repays a portion of the debt and receives discounted collateral in return.

```
exchange_rate    = (collateral_scale / debt_scale) × (debt_price / collateral_price)

liquidator_gets  = actual_repay × exchange_rate / (1 − liq_discount)
protocol_gets    = actual_repay × exchange_rate × liq_revenue_factor
```

where `liq_revenue_factor = liq_penalty − liq_discount`.

**Liquidator profit** = value of collateral received − value of debt repaid = `liq_discount` percentage of the repaid value.

**Borrower outcome** = remaining collateral after liquidator and protocol shares are deducted.

**Per-call cap**: 20 % of total debt value per liquidation call. See the full spec: [liquidation-mechanism.md](../liquidation-mechanism.md).

---

## Utilization and Rate Dynamics

The 3-segment interest curve creates strong incentives to keep utilization in the optimal range:

```
Low utilization  (< mid_kink):   cheap rates    → borrows encouraged
Mid utilization  (mid → high):   rising rates   → balance maintained
High utilization (> high_kink):  steep rates    → suppliers rush in, borrowers exit
```

This self-balancing mechanism keeps the pool liquid without requiring manual rate management.

---

## Borrow Weight

`borrow_weight` (1.0–5.0×) is applied to a debt type when computing how much collateral it consumes:

```
collateral_required_for_borrow
  = debt_amount × price × borrow_weight / collateral_price / collateral_factor
```

High-risk assets carry a higher `borrow_weight`, requiring proportionally more collateral. This is also the same weight used in the liquidation health check (`weighted_debts_value`), so riskier debts bring positions to liquidation threshold faster.
