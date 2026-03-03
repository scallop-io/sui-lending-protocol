# Scallop Protocol — Architecture Overview

> Over-collateralized lending & borrowing on Sui · Move · Version 9

---

## What Is Scallop?

Scallop is an over-collateralized lending protocol where users can **supply** assets to earn yield or **borrow** assets against collateral. The protocol runs on Sui and is written in Move.

The defining feature is **segregated collateral**: each borrower's collateral lives in their own `Obligation` object rather than a shared pool. Lender funds and borrower collateral are completely separate. Collateral only becomes accessible to liquidators when a borrower's health drops below the liquidation threshold.

---

## Layered Architecture

```
┌────────────────────────────────────────────────────────┐
│              User / External PTB / Bot                 │
└──────────────────────────┬─────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │   User Operation Layer  │  mint · redeem · borrow · repay
              │   sources/user/         │  deposit/withdraw collateral
              └──────┬──────────┬───────┘  liquidate · flash_loan
                     │          │
          ┌──────────▼──┐  ┌────▼────────────┐
          │  Evaluator  │  │  Obligation      │
          │  Layer      │  │  Layer           │
          │ sources/    │  │ sources/         │
          │ evaluator/  │  │ obligation/      │
          └──────┬──────┘  └────────────────-─┘
                 │
          ┌──────▼──────────────────────────────┐
          │           Market Layer               │
          │  sources/market/                     │
          │  Market · Reserve · BorrowDynamics   │
          │  InterestModel · RiskModel · Limiter │
          │  APM · CollateralStats               │
          └──────────────────────────────────────┘
                 │
          ┌──────▼──────────────────────────────┐
          │        App / Admin Layer             │
          │  sources/app/ · sources/version/     │
          │  sources/referral/                   │
          └──────────────────────────────────────┘
```

---

## Detailed Documentation

Each section below maps to a file in `docs/` that mirrors the `sources/` directory structure.

| Layer | Sources | Docs |
|---|---|---|
| Market | `sources/market/` | [docs/market/](docs/market/README.md) |
| Obligation | `sources/obligation/` | [docs/obligation/](docs/obligation/README.md) |
| User Operations | `sources/user/` | [docs/user/](docs/user/README.md) |
| Evaluators | `sources/evaluator/` | [docs/evaluator/](docs/evaluator/README.md) |
| App / Admin / Version / Referral | `sources/app/` `sources/version/` `sources/referral/` | [docs/app/](docs/app/README.md) |

Cross-cutting topics:

| Topic | Docs |
|---|---|
| Economic model (interest, pricing, fees) | [docs/economic-model.md](docs/economic-model.md) |
| Safety mechanisms (APM, rate limiter, health checks) | [docs/safety.md](docs/safety.md) |
| Liquidation mechanism (full spec) | [liquidation-mechanism.md](liquidation-mechanism.md) |
| Design patterns (hot potato, witness, delayed changes) | [docs/design-patterns.md](docs/design-patterns.md) |

---

## Key Invariants (Quick Reference)

| Invariant | Enforced at |
|---|---|
| `Reserve.cash >= Reserve.revenue` | Every withdrawal |
| Market coin price is non-decreasing | Redemption path |
| `borrow_index` only grows | Compounding formula |
| At most one lock per Obligation | `Option<TypeName>` semantics |
| `global_collateral ≤ max_collateral_amount` | `deposit_collateral` |
| `liquidation_factor > collateral_factor` | `create_risk_model_change` |
| Flash loans repaid in same transaction | Hot potato; cannot be dropped |
| Obligations are always shared objects | Hot potato on `open_obligation` |
