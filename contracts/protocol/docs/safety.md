# Safety Mechanisms

The protocol layers multiple independent defenses. A vulnerability that bypasses one layer is still constrained by the others.

---

## 1. Health Checks

Every borrow and collateral withdrawal asserts the position remains healthy after the operation:

```
max_borrow_usd = collaterals_value_for_borrow − weighted_debts_value
               = Σ(price_i × coll_i × collateral_factor_i)
               − Σ(price_j × debt_j × borrow_weight_j)
```

If `max_borrow_usd ≤ 0`, the operation aborts. The evaluator returns `0` rather than a negative number, so callers can safely use it as a ceiling.

Implemented in: `sources/evaluator/borrow_withdraw_evaluator.move`

---

## 2. Advanced Price Monitor (APM)

**Threat:** An attacker takes a flash loan to temporarily spike an oracle price, then borrows far more than their collateral warrants before the price reverts.

**Defense:** The APM tracks the minimum oracle price over a rolling 24-hour window (24 hourly buckets). Before any borrow or collateral withdrawal is finalized, it checks:

```
if current_price > threshold × min_price_24h:
    abort  // price looks manipulated
```

Only upward spikes are flagged. A downward price move is unfavorable to an attacker trying to inflate collateral value, so it does not trigger the guard.

The APM state can be refreshed by anyone (`refresh_apm_state<T>` is public), ensuring fresh price data is always available.

Implemented in: `sources/app/apm.move`

---

## 3. Rate Limiter (Outflow Limiter)

**Threat:** A coordinated withdrawal of all liquidity in a short window (bank run or exploit drain).

**Defense:** Each asset has a rolling outflow limit. The cycle (e.g., 24 h) is divided into fixed segments (e.g., 30 min). Each segment tracks net outflow (borrows + redeems − repayments). The sum across all active segments must stay below `outflow_limit`.

```
net_outflow_this_cycle = Σ segment.outflow  for each segment in current cycle
assert net_outflow_this_cycle + new_outflow ≤ outflow_limit
```

Repayments reduce the current segment's outflow, giving credit for inflows. This prevents an attacker from draining the pool in one transaction while still allowing normal repayment activity to restore capacity within the same cycle.

Limiter parameters are updated with a governance delay to prevent sudden limit changes. See [governance delays](app/README.md#governance-delays).

Implemented in: `sources/market/limiter.move`

---

## 4. Liquidation 20% Cap

**Threat:** A liquidator repays the entire debt in one call, stripping so much collateral that the remaining obligation has fresh bad debt (collateral insufficient to cover remaining debt).

**Defense:** Each liquidation call is capped at **20% of the total debt value** across all debt types:

```
max_repay_usd    = total_debts_value_usd × 0.20
max_repay_amount = max_repay_usd / debt_price × debt_scale
```

This makes liquidations gradual. After each call the position's health improves; if still unhealthy, another call may follow. Cascading bad debt is prevented because each step removes only a bounded fraction of collateral.

**Exception — dust positions:** When `total_debts_value < $10`, a full one-shot repay is allowed. Gas costs would otherwise exceed any partial liquidation incentive, leaving the dust position permanently underwater.

Full liquidation spec: [liquidation-mechanism.md](../liquidation-mechanism.md)

Implemented in: `sources/evaluator/liquidation_evaluator.move`

---

## 5. Obligation Locking

**Threat:** A malicious or buggy integration re-enters an obligation mid-operation, reading stale state.

**Defense:** Two layers of locks on `Obligation`:

1. **Per-operation flags** (`borrow_locked`, `repay_locked`, `deposit_collateral_locked`, `withdraw_collateral_locked`, `liquidate_locked`) — external integrations set these to prevent specific operations while managing a position.

2. **Exclusive lock key** (`lock_key: Option<TypeName>`) — at most one lock type is active at a time. Acquiring a lock while another is held aborts. The lock key type must be registered in `ObligationAccessStore` by the admin.

This prevents unauthorized packages from acquiring locks and enables safe composability with trusted integrations.

Implemented in: `sources/obligation/obligation.move`, `sources/obligation/obligation_access.move`

---

## 6. Whitelist and Emergency Pause

All public entry points call `assert_whitelist(market, ctx.sender())`. The whitelist operates in two modes:

- **Normal mode**: only addresses on the whitelist may interact.
- **Reject-all mode** (circuit breaker): all calls abort regardless of sender. Activated via `freeze_protocol()` by the admin.

This enables both fine-grained access control (permissioned launch, gradual rollout) and an emergency pause that stops all protocol activity instantly.

Implemented in: `sources/market/market.move`, `sources/app/app.move`

---

## 7. Isolated Assets

High-risk or thinly-traded assets can be marked **isolated**. An obligation borrowing an isolated asset cannot simultaneously borrow any non-isolated assets, and vice versa.

This prevents a single volatile asset from affecting a multi-asset borrower's portfolio and limits contagion if the isolated asset's oracle or liquidity fails.

Implemented in: `sources/user/borrow.move` (`assert_isolated_asset`)

---

## 8. Reserve Solvency Invariant

`Reserve.cash >= Reserve.revenue` is asserted before every withdrawal operation. `revenue` is the protocol's earmarked portion of interest and is never mixed with the `cash` available to depositors. Breaking this invariant would mean the protocol owes depositors more than it holds in liquid form.

Implemented in: `sources/market/reserve.move`

---

## 9. Version Gate

Every public entry point asserts `version.value == CURRENT_VERSION`. After an upgrade, calls to outdated code immediately abort. This prevents exploits that rely on interacting with an old version of the protocol that lacks a fix.

Implemented in: `sources/version/version.move`, `sources/version/current_version.move`
