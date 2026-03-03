# Obligation Layer

> `sources/obligation/`

An `Obligation` is the per-user position object. It holds a borrower's collateral coins and tracks their outstanding debts. Each user creates one or more obligations; each is a shared Sui object paired with an owned `ObligationKey` that proves ownership.

---

## Modules

| File | Purpose |
|---|---|
| `obligation.move` | Main position object, locking, interest accrual |
| `obligation_debts.move` | Per-debt amount + borrow index snapshot |
| `obligation_collaterals.move` | Per-collateral amount tracking |
| `obligation_access.move` | Registry of authorized lock and reward key types |
| `obligation_key_display.move` | Display metadata for `ObligationKey` |

---

## Object Model

```
Obligation (shared)                   ObligationKey (owned by user)
──────────────────────────────        ──────────────────────────────
balances: BalanceBag                  id: UID
  └─ Balance<CollateralCoin> × N      ownership: Ownership<ObligationOwnership>
debts: WitTable
  └─ Debt × TypeName
collaterals: WitTable
  └─ Collateral × TypeName
lock_key: Option<TypeName>
borrow_locked: bool
repay_locked: bool
deposit_collateral_locked: bool
withdraw_collateral_locked: bool
liquidate_locked: bool
rewards_point: u64
```

**Pairing:** `Obligation.id` and `ObligationKey.ownership` reference each other. Operations that require owner authorization (e.g., `withdraw_collateral`) call `assert_obligation_owner` which verifies the key matches the obligation.

---

## `obligation.move`

### Creation

`new()` returns a paired `(Obligation, ObligationKey)`. The obligation is wrapped in an `ObligationHotPotato` that **must** be consumed by `return_obligation`, which calls `transfer::share_object`. This guarantees obligations are always shared — they cannot be trapped or dropped silently.

### Interest Accrual

```move
public(friend) fun accrue_interests(
  obligation: &mut Obligation,
  market: &Market,
)
```

Iterates over every debt type in the obligation and applies the index delta:

```
new_amount = stored_amount × (current_global_index / debt_snapshot_index)
```

This is called at the start of every user operation to ensure debt values are current before any health check or calculation.

### Locking

The locking system has two layers:

1. **Per-operation flags** (`borrow_locked`, `repay_locked`, etc.) — set by external integrations to prevent specific operations while a lock is held.
2. **Exclusive lock key** (`lock_key: Option<TypeName>`) — at most one lock type active at a time. The key type must be registered in `ObligationAccessStore`.

```move
public fun lock_obligation<LockKey: drop>(
  obligation: &mut Obligation,
  access_store: &ObligationAccessStore,
  _key: LockKey,
)
```

The `LockKey` witness proves the caller has the authorized key type. Attempting to acquire a second lock while one is held aborts.

---

## `obligation_debts.move`

```move
struct Debt {
  amount:       u64,  // principal at time of last index update
  borrow_index: u64,  // global borrow_index snapshot when this value was last updated
}
```

**Interest application:**

```move
fun accrue_interest(debt: &mut Debt, current_index: u64) {
  debt.amount = debt.amount * current_index / debt.borrow_index;
  debt.borrow_index = current_index;
}
```

The `borrow_index` snapshot is updated every time interest is applied, so repeated calls are idempotent.

---

## `obligation_collaterals.move`

```move
struct Collateral { amount: u64 }
```

Tracks the deposited amount per collateral type. The actual `Balance<T>` coins live in `Obligation.balances` (a `BalanceBag`). Amounts are removed from the table when they reach zero (no dust entries).

---

## `obligation_access.move`

```move
struct ObligationAccessStore {
  id: UID,
  lock_keys:   VecSet<TypeName>,
  reward_keys: VecSet<TypeName>,
}
```

A shared singleton maintained by the admin. External integrations that want to lock obligations or distribute rewards must have their witness type registered here first. This prevents unauthorized packages from acquiring locks.

---

## Relationship to Market

`Obligation` does **not** hold a reference to `Market`. The user operation layer passes both as arguments and coordinates between them. This keeps the obligation layer self-contained and independently testable.

Collateral coins are held directly in `Obligation.balances`, completely separate from the `Reserve` in `Market`. Only liquidation moves coins from an obligation's `BalanceBag` back into the market.
