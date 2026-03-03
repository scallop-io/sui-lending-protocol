# User Operation Layer

> `sources/user/`

All public entry points live here. Each module follows this execution order:

```
assert_current_version
  → assert_whitelist
  → accrue_all_interests          (market) / accrue_interests (obligation)
  → evaluate / health check       (evaluator layer)
  → mutate obligation
  → mutate market
  → emit event
```

---

## Modules

| File | Operation | Returns |
|---|---|---|
| `open_obligation.move` | Create obligation + key | `ObligationKey` (owned) |
| `mint.move` | Supply base asset | `MarketCoin<T>` (sCoin) |
| `redeem.move` | Burn sCoin → base asset | `Coin<T>` |
| `deposit_collateral.move` | Move collateral into obligation | — |
| `withdraw_collateral.move` | Remove collateral from obligation | `Coin<T>` |
| `borrow.move` | Borrow against collateral | `Coin<T>` |
| `repay.move` | Repay outstanding debt | — (excess refunded) |
| `liquidate.move` | Repay unhealthy debt → collateral | `(Coin<DebtType>, Coin<CollateralType>)` |
| `flash_loan.move` | Atomic intra-PTB loan | `(Coin<T>, FlashLoan<T>)` |
| `lock_obligation.move` | Acquire / release obligation lock | — |

---

## Open Obligation

```
open_obligation()
  → Obligation (shared) created
  → ObligationKey (owned) returned to caller
  → ObligationHotPotato must be consumed by return_obligation()
```

The **hot potato** pattern ensures `Obligation` is always shared. It cannot be stored or dropped — `return_obligation` must be called in the same PTB, which calls `transfer::share_object`.

---

## Supply (Mint)

```
mint<T>(coin: Coin<T>) → MarketCoin<T>
  → check supply limit (dynamic field on Market)
  → reserve::mint_market_coin<T>
      BalanceSheet: cash ↑, market_coin_supply ↑
      sCoin issued at current exchange rate
```

Supply limits are configurable per asset via a dynamic field (`SupplyLimitKey<T>`). If the limit is reached the transaction aborts.

---

## Borrow

```
borrow<T>(obligation, key, amount) → Coin<T>
  → accrue all interests
  → assert obligation is healthy (collateral covers existing debts)
  → assert no isolated asset conflict
  → evaluator: max_borrow_amount<T> ≥ amount
  → assert amount ≥ min_borrow_amount (interest model param)
  → assert amount ≤ borrow limit (dynamic field on Market)
  → APM check: price not spiking
  → rate limiter: outflow within cycle limit
  → obligation::increase_debt<T>
  → market::handle_borrow<T>  →  reserve: cash ↓, debt ↑
```

### Isolated Asset Rule

If the borrowed asset is marked **isolated**, the obligation must not have any non-isolated debts (and vice versa). This prevents a volatile isolated asset from contaminating a multi-asset borrower's portfolio.

### Referral Discounts

`borrow_with_referral<T, Witness>` accepts a `BorrowReferral<T, Witness>` hot potato. The witness type must be on the authorized list. The borrow fee is reduced by the referral discount, and a portion flows to the referral provider. See [Referral](../app/README.md#referral).

---

## Repay

```
repay<T>(obligation, coin: Coin<T>)
  → accrue interests
  → actual_repay = min(coin.value, obligation.debt<T>)
  → obligation::decrease_debt<T>
  → market::handle_repay<T>  →  reserve: cash ↑, debt ↓
  → excess coin refunded to sender
```

Any address may repay — not just the obligation owner.

---

## Deposit Collateral

```
deposit_collateral<T>(obligation, key, coin: Coin<T>)
  → assert risk_model exists for T  (T is an approved collateral type)
  → assert collateral asset is active
  → assert coin.value ≥ min_collateral_amount
  → assert global_collateral_amount + coin.value ≤ max_collateral_amount
  → obligation: deposit coin into balances, increase collateral amount
  → market: increase collateral_stat
```

---

## Withdraw Collateral

```
withdraw_collateral<T>(obligation, key, amount) → Coin<T>
  → accrue interests
  → evaluator: max_withdraw_amount<T>  (keeps position healthy)
  → assert amount ≤ max_withdraw
  → APM check
  → obligation: withdraw coin, decrease collateral amount
  → market: decrease collateral_stat
```

---

## Liquidate

```
liquidate<DebtType, CollateralType>(obligation, repay_coin)
  → (Coin<DebtType>, Coin<CollateralType>)
```

Full liquidation spec: [liquidation-mechanism.md](../../liquidation-mechanism.md)

**Summary:**
1. Accrue interests.
2. Assert position is liquidatable (`weighted_debts > collaterals_for_liquidation`).
3. Cap repay at 20 % of total debt value (or full repay if dust < $10).
4. Compute collateral splits: liquidator share (with discount) + protocol share.
5. Withdraw collateral from obligation, decrease obligation debt.
6. Market: accept repay balance, record protocol collateral as revenue.
7. Return unused repay coin to liquidator + liquidator collateral.

---

## Flash Loan

```
borrow_flash_loan<T>(market, amount) → (Coin<T>, FlashLoan<T>)
  ...arbitrary PTB actions...
repay_flash_loan<T>(market, coin, receipt: FlashLoan<T>)
  → assert repay ≥ borrowed + fee
  → reserve: cash ↑, revenue ↑ (fee)
  → excess refunded
```

`FlashLoan<T>` is a **hot potato** — it has no `drop` ability. It must be consumed by `repay_flash_loan` in the same transaction, enforcing atomic repayment.

---

## Event Reference

| Event | Emitted by |
|---|---|
| `ObligationCreatedEvent` | `open_obligation` |
| `MintEvent` | `mint` |
| `RedeemEvent` | `redeem` |
| `CollateralDepositEvent` | `deposit_collateral` |
| `CollateralWithdrawEvent` | `withdraw_collateral` |
| `BorrowEventV3` | `borrow` |
| `RepayEvent` | `repay` |
| `LiquidateEventV2` | `liquidate` |
| `BorrowFlashLoanV2Event` | `flash_loan` |
| `RepayFlashLoanV2Event` | `flash_loan` |

Events use versioned names (V2, V3) to allow schema evolution while preserving event history.
