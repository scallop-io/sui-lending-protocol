# App / Admin Layer

> `sources/app/` · `sources/version/` · `sources/referral/`

---

## Modules

| File | Purpose |
|---|---|
| `app/app.move` | Protocol initialization, `AdminCap`, all admin operations |
| `app/apm.move` | Advanced Price Monitor — price history tracking |
| `version/version.move` | Shared `Version` object and `VersionCap` |
| `version/current_version.move` | Hardcoded `CURRENT_VERSION = 9` constant |
| `referral/borrow_referral.move` | Extensible borrow fee discount system |

---

## `app.move` — AdminCap and Protocol Initialization

`init()` creates the singleton `Market` and `AdminCap`. The `AdminCap` is the root authority for all configuration changes.

### Admin Operations

**Asset configuration:**

| Function | Effect |
|---|---|
| `add_risk_model<T>` | Register collateral type with risk parameters |
| `update_risk_model<T>` | Apply a pending (delayed) risk model change |
| `add_interest_model<T>` | Register borrowable asset with rate curve |
| `update_interest_model<T>` | Apply a pending (delayed) interest model change |
| `set_base_asset_active_state<T>` | Enable / disable supply & borrow for an asset |
| `set_collateral_active_state<T>` | Enable / disable collateral deposits for an asset |
| `update_isolated_asset_status<T>` | Mark / unmark an asset as isolated |

**Limits and fees:**

| Function | Effect |
|---|---|
| `update_supply_limit<T>` | Cap total supply for an asset |
| `update_borrow_limit<T>` | Cap total borrow for an asset |
| `update_min_collateral_amount<T>` | Minimum deposit per collateral tx |
| `set_flash_loan_fee<T>` | Flash loan fee in basis points (0–10 000) |
| `update_borrow_fee<T>` | One-time borrow fee |

**Rate limiter:**

| Function | Effect |
|---|---|
| `add_limiter<T>` | Register outflow limiter for an asset |
| `apply_limiter_limit_change<T>` | Apply pending outflow limit change |
| `apply_limiter_params_change<T>` | Apply pending segment/cycle duration change |

**Revenue:**

| Function | Effect |
|---|---|
| `take_revenue<T>` | Withdraw protocol interest revenue |
| `take_borrow_fee<T>` | Withdraw accumulated borrow fees |

**Access control:**

| Function | Effect |
|---|---|
| `add_whitelist_address` | Allow an address to interact with the protocol |
| `remove_whitelist_address` | Remove an address from the whitelist |
| `freeze_protocol` | Switch whitelist to reject-all mode (emergency pause) |

**Referral:**

| Function | Effect |
|---|---|
| `add_referral_witness<W>` | Authorize a package witness type for referral |
| `remove_referral_witness<W>` | Revoke a package's referral authorization |

---

## Governance Delays

Interest model and risk model changes — and rate limiter parameter updates — use a `OneTimeLockValue<T>` with a minimum **7-epoch delay** (≈ 7 days on Sui). The flow is:

```
admin: create_interest_model_change<T>(...)   →  OneTimeLockValue<InterestModel>
  (locked for ≥ 7 epochs)

admin: update_interest_model<T>(change)       →  model applied to market
```

The delay gives users a window to react (e.g., withdraw before a rate increase takes effect) and prevents governance flash attacks.

---

## `version.move` — Upgrade Gate

```move
struct Version { id: UID, value: u64 }
struct VersionCap { id: UID }
```

Every public-facing function calls `assert_current_version(version)`. If `version.value != CURRENT_VERSION`, the call aborts.

**Upgrade flow:**
1. Deploy new package with incremented `CURRENT_VERSION`.
2. Call `version::upgrade(version, cap)` to bump the on-chain value.
3. All calls to the old package immediately start aborting.

This is a lightweight but effective upgrade gate. The `VersionCap` is held by the deployer; it cannot be transferred.

---

## `referral/borrow_referral.move`

Allows external packages (e.g., point aggregators, partner protocols) to offer borrow fee discounts to their users.

### Objects

```move
// Hot potato — must be created and destroyed in the same PTB
struct BorrowReferral<phantom CoinType, phantom Witness: drop> {
  discount:     u64,   // fee reduction (out of BASE = 100)
  referral_fee: u64,   // referral provider's share (out of BASE = 100)
  // dynamic fields: BorrowedKey (u64), ReferralFeeKey (Balance<CoinType>)
}

// Shared singleton managed by admin
struct AuthorizedWitnessList { id: UID }
```

### Authorization

The `Witness` type parameter must be registered in `AuthorizedWitnessList` before a referral can be created. Only the admin can add or remove witnesses.

### Fee Calculation

```
discounted_fee   = original_fee × discount / BASE
referral_fee_cut = original_fee × referral_fee / BASE
net_protocol_fee = original_fee − discounted_fee
```

The referral provider calls `destroy_borrow_referral` at the end of the PTB to extract the accumulated fee balance.

### Custom Config

External packages can attach arbitrary config data to a `BorrowReferral` via `add_referral_cfg<Cfg>` / `get_referral_cfg<Cfg>` / `remove_referral_cfg<Cfg>` — useful for storing per-referral metadata without protocol changes.
