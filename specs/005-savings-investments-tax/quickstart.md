# Quickstart — Domain Layer II (Savings, Investments & Tax)

**Feature**: `005-savings-investments-tax` | Build, seed, and exercise the Phase 4 engines.

> Prereq: Phase 3 (`004-domain-accounts-budget-overview`) merged. CLT-only boxes can `swift build` and
> run the CLIs but not `swift test` (needs full Xcode; runs in macOS CI).

## 1. Build

```bash
swift build          # library, app, and all CLIs (4 new targets added this phase)
```

## 2. Provision + seed a dev workspace

```bash
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance          # seeds standard adjustment + new files
swift run fixture-generate    --workspace ~/Finance-Dev --months 12      # assets/prices/trades/dividends/sp500/goals/tax
swift run validate-workspace  --workspace ~/Finance-Dev/Finance          # MUST report zero errors (SC-010)
```

## 3. Run the new projection CLIs

```bash
swift run savings-overview    --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run portfolio-overview  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30 [--account <id>]
swift run benchmark-overview  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run tax-overview        --workspace ~/Finance-Dev/Finance --tax-year 2026
swift run overview-dashboard  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30   # all 5 cards now live
```

## 4. The two safe writes (preview by default)

```bash
swift run tax-overview --workspace ~/Finance-Dev/Finance --tax-year 2026 --seed-standard            # preview
swift run tax-overview --workspace ~/Finance-Dev/Finance --tax-year 2026 --seed-standard --apply    # write (backup+atomic)
swift run tax-overview --workspace ~/Finance-Dev/Finance --tax-year 2025 --close-year               # preview archive
swift run tax-overview --workspace ~/Finance-Dev/Finance --tax-year 2025 --close-year --apply       # year-close
```

## 5. Verify (what "done" looks like)

- `portfolio-overview` shows positions with current value/cost/unrealized; an asset with no price prints
  **"price unavailable"**; sleeve drift = actual − target; dividend totals present.
- `tax-overview` shows per-account taxable income/paid/effective rate; realized gains **split ST/LT**
  (FIFO); a deduction summary with standard **and** itemized totals and the greater flagged; a tax
  estimate (computed, or stored override); the prep checklist with complete/incomplete/missing items.
- `benchmark-overview` shows the 8-period heat map; a too-old period prints **"insufficient history"**;
  weekend/holiday anchors resolve to the last prior close.
- `savings-overview` shows months-to-goal at the trailing-3-month rate (or **"n/a"**); a snapshot-less
  goal uses the ledger-derived balance; archived goals are absent.
- `overview-dashboard` shows all **five** live cards; an Investments/Savings card without a stored rate
  prints **"rate not set"**.

## 6. Tests (macOS CI / full Xcode)

```bash
swift test                 # SavingsGoal/Portfolio/Benchmark/Tax/TaxAdjustment/TaxPrep + Linking/Overview/Mappers/Seed
swiftlint --strict         # CI-enforced before merge
```
