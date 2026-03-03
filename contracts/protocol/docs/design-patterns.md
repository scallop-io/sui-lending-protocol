# Design Patterns

Common Move patterns used across the protocol and the reasoning behind each.

---

## Hot Potato

A struct with no `key`, `store`, or `drop` ability. It cannot be stored in another object, saved to global storage, or silently dropped. The only way to consume it is to call the designated destruction function in the same transaction.

**Used for:**

| Type | Enforced invariant |
|---|---|
| `ObligationHotPotato` | `return_obligation` must be called → obligation is always shared |
| `FlashLoan<T>` | `repay_flash_loan` must be called → loan is always repaid |
| `BorrowReferral<CoinType, Witness>` | `destroy_borrow_referral` must be called → fees are always extracted |

This pattern eliminates entire classes of bugs where an intermediate object could be forgotten or mishandled, with zero runtime overhead.

---

## Witness / One-Time Witness

A struct with only `drop` (and sometimes `copy`) that proves the caller is from a specific module or package.

**Used for:**

| Witness | Proves |
|---|---|
| `Ownership<ObligationOwnership>` in `ObligationKey` | The key holder owns the paired obligation |
| `Witness: drop` parameter on `BorrowReferral` | The caller is the authorized partner package |
| `WitTable` internal witnesses | Only the owning module may mutate the table |

The key insight: if a function accepts `_witness: Witness` and `Witness` is only constructible inside module `M`, then only code from `M` can call that function. This is Move's capability pattern — authorization is structural, not runtime-checked.

---

## Delayed One-Time Change (`OneTimeLockValue`)

A value that is locked for a minimum number of epochs before it can be extracted — and can only be extracted once.

```
create_*_change(...)  →  OneTimeLockValue<T> { value, unlock_at_epoch }

apply_*_change(change)
  → assert clock.epoch >= unlock_at_epoch
  → extract value (consumes the OneTimeLockValue)
```

**Used for:** Interest model updates, risk model updates, rate limiter parameter updates.

**Why:** Prevents governance flash attacks where an admin could instantly change parameters (e.g., raise liquidation factors to liquidate healthy positions) and exploit users in the same transaction. The 7-epoch window gives users time to react.

---

## Layered Validation Order

Every public entry point validates in a fixed order:

```
1. assert_current_version        — stale code gate
2. assert_whitelist              — access control / circuit breaker
3. assert_obligation_key_match   — ownership (where applicable)
4. accrue_interests              — fresh state
5. business logic checks         — health, limits, APM, rate limiter
6. state mutations               — obligation, then market
7. emit event
```

Authorization checks always precede state mutations. This prevents partial-state exploits where a failed authorization check would leave the system in an inconsistent state.

---

## Witness-Gated Tables (`WitTable`, `AcTable`)

Internal tables that require a cryptographic proof of module identity for writes.

- `WitTable<Witness, K, V>`: mutations require a one-time witness for `Witness` (only constructible in the defining module).
- `AcTable<Cap, K, V>`: mutations require a capability object.

This means even if an attacker obtains a mutable reference to `Market`, they cannot modify `BorrowDynamics` or `CollateralStats` without the internal witness token — which only the market's own modules can produce.

---

## Per-Type Dynamic Fields

Limits, fees, and configuration that differ per asset type are stored as dynamic fields on `Market` keyed by typed structs:

```move
struct SupplyLimitKey<phantom T> has copy, drop, store {}
struct BorrowLimitKey<phantom T> has copy, drop, store {}
struct BorrowFeeKey<phantom T>   has copy, drop, store {}
// etc.
```

Benefits:
- `Market` schema does not change when new assets are added.
- Absent fields have defined fallback behavior (e.g., no limit = unlimited supply).
- Per-type access is O(1) regardless of how many assets exist.

---

## Versioned Events

When event schemas evolve, a new struct is introduced (`BorrowEventV2`, `BorrowEventV3`) rather than modifying the existing one. Old event types are kept so historical indexers remain valid.

This allows the protocol to add fields (e.g., including the borrow fee in V3) without breaking downstream consumers that still filter on V1/V2 events.

---

## Composition over Inheritance

Move has no inheritance. The protocol composes behavior by embedding specialized structs:

```
Market
  └── vault: Reserve            (asset custody)
  └── borrow_dynamics: …        (interest math)
  └── interest_models: …        (rate curves)
  └── risk_models: …            (collateral params)
  └── limiters: …               (outflow limits)

Obligation
  └── balances: BalanceBag      (actual coins)
  └── debts: WitTable           (debt tracking)
  └── collaterals: WitTable     (collateral tracking)
```

Each sub-struct has a narrow, well-defined interface. The parent orchestrates them but does not mix their concerns. This makes individual components independently testable and auditable.
