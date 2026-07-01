---
description: "Task list — Domain Layer II: Savings, Investments & Tax (Phase 4)"
---

# Tasks: Domain Layer II — Savings, Investments & Tax

**Input**: Design documents from `specs/005-savings-investments-tax/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: INCLUDED — the spec's per-story Independent Tests and Success Criteria are fixture/CLI
driven, and the repo runs `swift test` in `ci-macos.yml` (consistent with Phases 2–3). Each story ships
its own tests.

**Organization**: Tasks are grouped by user story. Build order follows research R8:
**US1 (Portfolio) → US2 (Tax) → US3 (TaxAdj/Prep)**, with **US4 (Benchmark)** after US1, **US5
(Savings)** independent, and **US6 (CrossDomain + Overview)** last (consumes all engines).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1–US6 (Setup/Foundational/Polish carry no story label)

## Path Conventions

Swift Package at repo root. Library code under `Sources/FinanceWorkspaceKit/`; CLI executables under
`Sources/<target>/`; tests under `Tests/FinanceWorkspaceKitTests/`. Phase 3 already created the
`Domain/{Savings,Investments,Taxes}/*Models.swift` stub files and the `Domain/Mapping/` seam — this
phase extends them.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the four new CLI targets and a clean build before any logic lands.

- [X] T001 [P] Create CLI source folders: `Sources/savings-overview/`, `Sources/portfolio-overview/`, `Sources/benchmark-overview/`, `Sources/tax-overview/`
- [X] T002 Register four `.executableTarget`s (`savings-overview`, `portfolio-overview`, `benchmark-overview`, `tax-overview`) depending on `FinanceWorkspaceKit` in `Package.swift`, each with a stub `main.swift` that prints usage and exits 2, so the package builds
- [X] T003 [P] Confirm `swift build` and `swiftlint --strict` are green on the scaffold

**Checkpoint**: Package builds with empty CLI targets; folders exist.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `ParsedRecord` → typed-entity mappers for the new file types, the shared period/date
math (benchmark anchoring, CAGR, holding-period), the standard-deduction + tax-bracket tables, the new
seed files and the optional estimated-rate schema columns, and the shared hand-authored fixtures every
engine and story depends on. ⚠️ No engine work can start until this phase is complete.

- [X] T004 Extend `RecordMappers` with the 14 new mappers (asset, pricePoint, trade [`type = trade` ledger rows], dividend, portfolio, sleeve, sleeveTarget, benchmarkPoint, savingsGoal, savingsProgress, taxAdjustment, taxEstimate, taxDocument, estimatedPayment), reading from `FieldValue.typed`, returning `nil` on missing/invalid required fields, preserving provenance, in `Sources/FinanceWorkspaceKit/Domain/Mapping/RecordMappers.swift` per `contracts/record-mapping.md`
- [X] T005 Add `WorkspaceContext` accessors for the new entities (assets; prices indexed `[ticker: [sorted PricePoint]]`; trades; dividends; portfolios; sleeves; sleeveTargets; the sorted `sp500` benchmark series; savingsGoals; latest-by-goal savingsProgress; taxAdjustments; taxEstimates; taxDocuments; estimatedPayments) as an extension in `Sources/FinanceWorkspaceKit/Domain/Mapping/RecordMappers.swift` per `data-model.md §A`
- [X] T006 [P] Extend `PeriodMath` with the 8-`BenchmarkPeriod` calendar-anchored start dates, `lastCloseOnOrBefore` lookup, the CAGR helper, and a holding-period (>365-day) helper in `Sources/FinanceWorkspaceKit/Domain/Mapping/PeriodMath.swift` per research R1/R2
- [X] T007 [P] Add the standard-deduction **and tax-bracket** hardcoded `[filingStatus: [taxYear: …]]` tables and seed empty-but-valid new files (dividends, portfolios, sleeves, sleeve-targets, benchmarks/sp500, progress, estimates, documents) in `Sources/FinanceWorkspaceKit/Platform/WorkspaceLayout.swift` per `contracts/seed-data.md §1,§1a,§3`
- [X] T008 [P] Register the optional estimated-rate columns — `expected_return_rate` in `Sources/FinanceWorkspaceKit/Resources/Schemas/portfolios.schema.json` + `CSVSchemaRegistry`, and confirm/add the savings APY (`interest_rate`) column in `Sources/FinanceWorkspaceKit/Resources/Schemas/accounts.schema.json` + `CSVSchemaRegistry` — as optional (non-breaking), so a workspace carrying them validates under strict schema enforcement, per FR-024a / `contracts/record-mapping.md`
- [X] T009 [P] Add the new-mapper coverage to `RecordMappersTests` (typed reads, nil-on-invalid-required, optional→nil incl. `expected_return_rate`, provenance carried) in `Tests/FinanceWorkspaceKitTests/Unit/RecordMappersTests.swift`
- [X] T010 [P] Add the shared hand-authored fixtures under `Tests/FinanceWorkspaceKitTests/Fixtures/`: a FIFO multi-lot buy-then-partial-sell spanning the 1-year ST/LT boundary; a price series with a missing ticker; an `sp500` series with weekend/holiday gaps and a too-short history (5Y before series start); a no-snapshot goal + an archived goal + goal-tagged contributions; a `business-expense` Schedule C adjustment on a business account-group; `estimates.csv` with one stored-override and one empty row; a closed prior year under `Taxes/archive/`; dividend + interest rows — so each story's tests run independently

**Checkpoint**: Engines can consume typed entities + period math from any `WorkspaceContext`; the
tables, seed files, optional columns, and every story's fixtures exist. User-story work can now begin.

---

## Phase 3: User Story 1 — Investment portfolio read model (Priority: P1) 🎯 MVP

**Goal**: `PortfolioEngine` produces aggregate + per-account holdings: position value (`qty × latest
close`), cost basis, unrealized gain/loss, FIFO tax lots from `type = trade` rows, sleeve actual-vs-
target weight + drift, dividend totals; with a typed "price unavailable" state.

**Independent Test**: `swift run portfolio-overview --workspace <fixture> --as-of <date>` — positions
reconcile to assets/prices/trades, sleeve drift = actual − target (actual weights sum to 100%), an
asset with no price prints "price unavailable", dividend totals match.

- [X] T011 [P] [US1] Extend investment projection models (`Position` with `ValueState`, `TaxLot`, `SleeveAllocation`, `HoldingsProjection`) in `Sources/FinanceWorkspaceKit/Domain/Investments/InvestmentModels.swift` per `data-model.md §B`
- [X] T012 [US1] Implement FIFO tax-lot resolution per asset from `type = trade` rows (per-asset open-lot queue; sells consume oldest first) in `Sources/FinanceWorkspaceKit/Domain/Investments/PortfolioEngine.swift` per research R1 / FR-006
- [X] T013 [US1] Implement position current value (`quantity × lastCloseOnOrBefore(asOf)`), cost basis, and unrealized gain/loss, returning `.priceUnavailable` when the ticker has no price row, in `PortfolioEngine` per FR-005/FR-009
- [X] T014 [US1] Implement the `Portfolio → Sleeve → Asset` hierarchy and per-sleeve actual weight / target weight / drift from `sleeve-targets.csv` in `PortfolioEngine` per FR-007
- [X] T015 [US1] Implement dividend totals per asset/account (from `dividends.csv`) and assemble aggregate + `--account` `HoldingsProjection` in `PortfolioEngine` per FR-008 / `contracts/engine-contracts.md`
- [X] T016 [US1] Wire the `portfolio-overview` CLI (`--workspace`, `--as-of`, optional `--account`) in `Sources/portfolio-overview/main.swift` per `contracts/cli-scripts.md`
- [X] T017 [P] [US1] Add `PortfolioEngineTests` (FIFO multi-lot basis, drift sums to 100%, price-unavailable, dividend totals) asserting SC-002/SC-003 in `Tests/FinanceWorkspaceKitTests/Unit/PortfolioEngineTests.swift`

**Checkpoint**: US1 independently verifiable via the CLI and `swift test`. **MVP reached.**

---

## Phase 4: User Story 2 — Tax read model (Priority: P1)

**Goal**: `TaxEngine` computes per-account YTD taxable income, taxes paid, effective rate, realized
gain/loss **split short-term vs long-term** (FIFO), and dividend/interest aggregation.

**Independent Test**: `swift run tax-overview --workspace <fixture> --tax-year <YYYY>` — per-account
taxable income/paid/rate and ST/LT realized gains match hand-calcs for the fixture tax year.

- [ ] T018 [P] [US2] Extend tax projection models (`RealizedGainSummary` with ST/LT + `RealizedLot`, `AccountTaxProjection`) in `Sources/FinanceWorkspaceKit/Domain/Taxes/TaxModels.swift` per `data-model.md §B`
- [ ] T019 [US2] Implement realized gain/loss from trade + FIFO lot history, **split short-term vs long-term** by the >365-day holding period, in `Sources/FinanceWorkspaceKit/Domain/Taxes/TaxEngine.swift` per FR-016 / research R1 (reuses the US1 lot logic)
- [ ] T020 [US2] Implement per-account YTD taxable income (tax-year anchored), taxes paid from `estimated-payments.csv`, and effective rate (paid ÷ gross) in `TaxEngine` per FR-014/FR-015
- [ ] T021 [US2] Implement dividend (from `dividends.csv`) + interest (from interest-categorized ledger income rows) aggregation for the tax year in `TaxEngine` per FR-016 / research R7
- [ ] T022 [US2] Wire the read-only tax projection into the `tax-overview` CLI (`--workspace`, `--tax-year`: per-account income/paid/rate + ST/LT realized gains) in `Sources/tax-overview/main.swift` per `contracts/cli-scripts.md`
- [ ] T023 [P] [US2] Add `TaxEngineTests` (taxable income, ST/LT realized gains across the boundary fixture, effective rate, dividend/interest) asserting SC-005 in `Tests/FinanceWorkspaceKitTests/Unit/TaxEngineTests.swift`

**Checkpoint**: US2 verifiable independently; US1 still passes.

---

## Phase 5: User Story 3 — Tax adjustments, estimates, prep & archive (Priority: P2)

**Goal**: `TaxAdjustmentEngine` + `TaxPrepEngine` complete the Tax module — standard-vs-itemized
(compute both, flag greater), simplified QBI, business-expense cross-reference, computed tax estimate,
standard-adjustment seed, the prep checklist, and the year-close → read-only archive.

**Independent Test**: `swift run tax-overview --workspace <fixture> --tax-year <YYYY>` shows the
deduction summary, tax estimate (computed + stored override), and prep checklist; `--seed-standard`
and `--close-year` (with `--apply`) perform the two safe writes idempotently.

- [ ] T024 [P] [US3] Extend tax projection models (`TaxDeductionSummary`, `TaxEstimateProjection`, `TaxPrepSummary` + `PrepItem`, `TaxArchiveYear`) in `Sources/FinanceWorkspaceKit/Domain/Taxes/TaxModels.swift` per `data-model.md §B`
- [ ] T025 [US3] Implement `TaxDeductionSummary` in `Sources/FinanceWorkspaceKit/Domain/Taxes/TaxAdjustmentEngine.swift`: standard-deduction lookup, **standard-vs-itemized compute-both / flag-greater (no auto-commit)**, above-the-line + Schedule C, and a **simplified ≈20% QBI** on qualified business income (net income of `group_type = business` account-groups; no phaseouts), per FR-019 / research R3
- [ ] T026 [US3] Implement business-expense cross-reference (by `account_group_id`) against `AccountEngine` group expense totals, surfacing divergence, in `TaxAdjustmentEngine` per FR-020
- [ ] T027 [US3] Implement the computed `TaxEstimateProjection` (`projected_liability` from taxable-income-minus-adjustments at the filing-status bracket table; `target_safe_harbor` from prior-year liability) with a non-empty `estimates.csv` value as override, in `TaxAdjustmentEngine` per FR-017 / research R3
- [ ] T028 [US3] Implement `seedStandardAdjustmentIfMissing` (idempotent; one templated `standard` row from filing status + standard-deduction table) routed through `BackupService` + atomic apply + `WriteGate`, and logged to `.finance-meta/logs/repair-log.csv` as a create-missing-seed repair, in `TaxAdjustmentEngine` per FR-018 / research R6
- [ ] T029 [US3] Implement `TaxPrepEngine.prepSummary` (fixed v1 items: W-2 / 1099s / estimated payments / deduction confirmations; missing/incomplete/complete by source presence + confirmation; tax-relevant `ValidationIssue`s surfaced) in `Sources/FinanceWorkspaceKit/Domain/Taxes/TaxPrepEngine.swift` per FR-021 / research R3
- [ ] T030 [US3] Implement `TaxPrepEngine.archiveYear` (write `Taxes/archive/YYYY-tax-adjustments.csv` + `YYYY-estimated-payments.csv` via the safe-write path), `isYearClosed`, and read-only enforcement for a closed year, in `TaxPrepEngine` per FR-022 / research R6
- [ ] T031 [US3] Extend the `tax-overview` CLI with the deduction summary, tax estimate, prep checklist, and the `--seed-standard` / `--close-year` flags (preview by default; `--apply` to write) in `Sources/tax-overview/main.swift` per `contracts/cli-scripts.md`
- [ ] T032 [P] [US3] Add `TaxAdjustmentEngineTests` + `TaxPrepEngineTests` (seed idempotency, standard-vs-itemized flag, QBI, business x-ref, estimate + override SC-011, checklist states, year-close read-only SC-007) in `Tests/FinanceWorkspaceKitTests/Unit/TaxAdjustmentEngineTests.swift` and `.../TaxPrepEngineTests.swift`

**Checkpoint**: Tax module complete and verifiable; US1/US2 still pass.

---

## Phase 6: User Story 4 — Benchmark comparison & heat map (Priority: P2)

**Goal**: `BenchmarkEngine` loads the S&P 500 series and computes the 8-period heat map (simple ≤1Y /
CAGR 3Y–5Y) for the benchmark and each portfolio account, plus sector performance weights.

**Independent Test**: `swift run benchmark-overview --workspace <fixture> --as-of <date>` — each period
matches hand-calcs (simple vs CAGR), weekend/holiday anchors resolve to the last prior close, a too-old
period prints "insufficient history".

- [ ] T033 [P] [US4] Extend investment models (`BenchmarkCell` with `GrowthState`, `HeatMap`, `sectorPerformance`) in `Sources/FinanceWorkspaceKit/Domain/Investments/InvestmentModels.swift` per `data-model.md §B`
- [ ] T034 [US4] Implement `BenchmarkEngine`: load `benchmarks/sp500.csv`; compute the 8 periods via calendar anchor + `lastCloseOnOrBefore`; simple return ≤1Y, CAGR for 3Y/5Y; `.insufficientHistory` when the start anchor predates the series, in `Sources/FinanceWorkspaceKit/Domain/Investments/BenchmarkEngine.swift` per FR-010/FR-011/FR-013 / research R2
- [ ] T035 [US4] Implement per-account period growth (identical formula) + the `HeatMap` model (account × period, S&P row) + sector performance weights vs benchmark (`unclassified` bucket for assets without a sector) in `BenchmarkEngine` per FR-011/FR-012
- [ ] T036 [US4] Wire the `benchmark-overview` CLI (`--workspace`, `--as-of`) in `Sources/benchmark-overview/main.swift` per `contracts/cli-scripts.md`
- [ ] T037 [P] [US4] Add `BenchmarkEngineTests` (8 periods, CAGR vs simple, weekend-anchor carry-forward, insufficient-history) asserting SC-004 in `Tests/FinanceWorkspaceKitTests/Unit/BenchmarkEngineTests.swift`

**Checkpoint**: Benchmark heat map verifiable; needs US1 portfolio value series; US1–US3 still pass.

---

## Phase 7: User Story 5 — Savings goal progress (Priority: P2)

**Goal**: `SavingsGoalEngine` computes per-goal progress (snapshot-anchored else ledger-derived),
gap-to-target, months-to-goal at the trailing-3-month rate, and `GoalFundingLink`s; archived excluded,
completed derived.

**Independent Test**: `swift run savings-overview --workspace <fixture> --as-of <date>` — progress,
gap, months-to-goal (or "n/a"), and funding links match hand-calcs; a snapshot-less goal uses the
ledger balance; archived goals are absent.

- [ ] T038 [P] [US5] Extend `SavingsModels` with `GoalProgressProjection` (incl. `balanceSource`, `trailingContributionRate`, `isCompleteDerived`, `fundingLinks`) in `Sources/FinanceWorkspaceKit/Domain/Savings/SavingsModels.swift` per `data-model.md §B`
- [ ] T039 [US5] Implement `SavingsGoalEngine`: snapshot-anchored-else-ledger balance; gap-to-target; months-to-goal at the trailing-3-month contribution rate (`nil`/"n/a" when ≤0); `GoalFundingLink` resolution from `savings_goal_id`-tagged rows; exclude `archived`; derive `completed` from progress ≥ target, in `Sources/FinanceWorkspaceKit/Domain/Savings/SavingsGoalEngine.swift` per FR-001/002/003/004 / research R4
- [ ] T040 [US5] Wire the `savings-overview` CLI (`--workspace`, `--as-of`) in `Sources/savings-overview/main.swift` per `contracts/cli-scripts.md`
- [ ] T041 [P] [US5] Add `SavingsGoalEngineTests` (snapshot vs ledger balance, months-to-goal + "n/a", archived exclusion, derived-complete) in `Tests/FinanceWorkspaceKitTests/Unit/SavingsGoalEngineTests.swift`

**Checkpoint**: Savings goals verifiable independently (no dependency on US1–US4).

---

## Phase 8: User Story 6 — Cross-domain completion & live Overview (Priority: P3)

**Goal**: Extend `LinkingEngine` with portfolio-to-tax and Schedule C links; update `OverviewEngine`
so the Investments and Taxes cards carry live values (estimated rate from the stored field → "rate not
set" when absent), removing the Phase 3 stubs.

**Independent Test**: `swift run overview-dashboard --workspace <fixture> --as-of <date>` — all five
KPI cards live; an Investments/Savings card without a stored rate shows "rate not set"; realized gains
and Schedule C links resolve.

- [ ] T042 [P] [US6] Extend cross-domain models (`PortfolioTaxLink`, `ScheduleCLink`; live Investments/Taxes `OverviewSummaryCard`; `estimatedRate: RateState`) in `Sources/FinanceWorkspaceKit/Domain/CrossDomain/CrossDomainModels.swift` per `data-model.md §B`
- [ ] T043 [US6] Implement `LinkingEngine.portfolioTaxLinks` (realized gains → tax) and `scheduleCLinks` (business-expense adjustments → owning account-group) in `Sources/FinanceWorkspaceKit/Domain/CrossDomain/LinkingEngine.swift` per FR-023
- [ ] T044 [US6] Update `OverviewEngine` to compose the Investments card (from `PortfolioEngine`/`BenchmarkEngine`) and Taxes card (from the tax engines), remove the Phase-3 `dataNotAvailable` stubs, and source the Investments/Savings `estimatedRate` from the stored field with a `.rateNotSet` fallback, in `Sources/FinanceWorkspaceKit/Domain/CrossDomain/OverviewEngine.swift` per FR-024/FR-024a / research R5
- [ ] T045 [US6] Update the `overview-dashboard` CLI to render all five live cards in `Sources/overview-dashboard/main.swift` per `contracts/cli-scripts.md`
- [ ] T046 [P] [US6] Update `OverviewEngineTests` + `LinkingEngineTests` (live Investments/Taxes cards, "rate not set" SC-012, portfolio-to-tax + Schedule C links) in `Tests/FinanceWorkspaceKitTests/Unit/OverviewEngineTests.swift` and `.../LinkingEngineTests.swift`

**Checkpoint**: All five engines compose into a live Overview; whole suite green together.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Fixture generation, resilience + read-only guarantees, seed validation, docs, and the
Milestone 4 gate.

- [ ] T047 [P] Extend `fixture-generate` to emit the new file types (assets/prices/`type = trade` rows/dividends, a portfolio with sleeves + sleeve-targets, an `sp500` series, goals/progress, tax estimates/documents) in `Sources/fixture-generate/main.swift` per `contracts/seed-data.md §4`
- [ ] T048 [P] Update `SeedDataTests` so a fresh `bootstrap-workspace` validates with zero errors (SC-010), the four new CLIs produce non-empty projections on fixture output (SC-001), and every engine returns well-formed typed states (no crash/nil/misleading zero) on an empty, transaction-less workspace (FR-025 / Edge Cases), in `Tests/FinanceWorkspaceKitTests/Unit/SeedDataTests.swift`
- [ ] T049 [P] Add a read-only guarantee test: projection runs (excluding the two explicit `--apply` writes) leave workspace bytes unchanged (hash before/after) — SC-009 — extend `Tests/FinanceWorkspaceKitTests/Unit/ReadOnlyGuaranteeTests.swift`
- [ ] T050 [P] Add the four new `swift run …` lines plus the two `tax-overview --apply` actions to the Build & test block in `CLAUDE.md`
- [ ] T051 [P] Doc cascade per CLAUDE.md spec-completion workflow: update `docs/product-roadmap.md` Phase 4 status + Milestone 4, `docs/project-management.md`, `docs/out-of-scope-followups.md` (any Phase-4 items deferred), and `docs/test-plans.md` (engines now testable via the four CLIs)
- [ ] T052 Final `swift build` + `swiftlint --strict` + `swift test` pass; confirm the Milestone 4 gate (all domain engines functional; budget→goal, portfolio→tax, business→Schedule C links live; Overview composites all five KPI cards from real data) per `docs/product-roadmap.md`

---

## Dependencies & Execution Order

```
Phase 1 (Setup)            → T001 → T002 → T003
Phase 2 (Foundational)     → T004 → T005; T006,T007,T008,T009,T010 [P]   (BLOCKS all stories)
Phase 3 (US1 Portfolio, P1) 🎯 → T011 → T012 → T013 → T014 → T015 → T016; T017 [P]
Phase 4 (US2 Tax, P1)      → T018 → T019 → T020 → T021 → T022; T023 [P]   (T019 reuses US1 FIFO lots)
Phase 5 (US3 TaxAdj/Prep)  → T024 → T025 → T026 → T027 → T028 → T029 → T030 → T031; T032 [P]   (needs US2)
Phase 6 (US4 Benchmark, P2)→ T033 → T034 → T035 → T036; T037 [P]   (needs US1 value series)
Phase 7 (US5 Savings, P2)  → T038 → T039 → T040; T041 [P]   (independent — any time after Foundational)
Phase 8 (US6 Overview, P3) → T042 → T043 → T044 → T045; T046 [P]   (needs US1–US5 engines)
Phase 9 (Polish)           → T047,T048,T049,T050,T051 [P]; T052 last
```

- **Hard ordering**: US1 → US2 → US3 (Tax consumes portfolio realized gains; TaxAdj/Prep build on the
  tax read model). US4 needs US1's portfolio value series. US6's Overview consumes all engines.
- **US5 (Savings) is fully independent** — it can be built in parallel any time after Foundational.
- **Parallelism**: after Foundational, one developer can take US1→US2→US3 (the tax/investment spine)
  while another takes US5 (Savings) and prepares US4 fixtures.
- All shared fixtures + the standard-deduction/bracket tables + the optional schema columns live in
  Foundational (T007–T010), so each story's tests run independently.
- Foundational (T004–T010) blocks everything; do not start US tasks until it lands.

## Parallel Execution Examples

- **Foundational kick-off**: T004→T005 (same file, sequential), with T006, T007, T008, T009, T010 in
  parallel (distinct files).
- **Within US1**: T011 (model file) parallel-safe at the start; T017 (tests) parallel once T012–T016
  land — fixtures already exist from T010.
- **Across stories after Foundational**: US5 (T038–T041) runs alongside the US1→US2→US3 spine.
- **Polish**: T047–T051 all parallel (different files); T052 gates last.

## Implementation Strategy

- **MVP = Phase 1 + Phase 2 + Phase 3 (US1)** — a verifiable investment portfolio read model (the
  largest new surface and the realized-gain source for Tax). Ship/checkpoint here.
- **Increment 2**: US2 (Tax) + US3 (TaxAdj/Prep) — the second Milestone-4 core; removes the Taxes stub.
- **Increment 3**: US4 (Benchmark) + US5 (Savings) in parallel — heat map and goals.
- **Increment 4**: US6 (CrossDomain/Overview) — live five-card Overview, proving Milestone 4.
- **Close-out**: Phase 9 — fixtures, resilience + read-only proof, doc cascade, Milestone 4 gate.

## Task Summary

- **Total**: 52 tasks (T001–T052)
- **By story**: Setup 3 · Foundational 7 · US1 7 · US2 6 · US3 9 · US4 5 · US5 4 · US6 5 · Polish 6
- **Parallel-marked [P]**: 22 tasks
- **Tests**: 8 test tasks (RecordMappers, Portfolio, Tax, TaxAdjustment+TaxPrep, Benchmark,
  SavingsGoal, Overview+Linking, SeedData/ReadOnlyGuarantee) — one+ per story; shared fixtures +
  standard-deduction/bracket tables + optional schema columns are foundational
- **Two safe writes**: standard-adjustment seed (T028) and year-close archive (T030) — the only writes,
  both via the Phase 1 safe-write primitives; the seed is logged as a create-missing-seed repair
- **Suggested MVP**: T001–T017 (through US1)
