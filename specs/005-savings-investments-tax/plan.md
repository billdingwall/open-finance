# Implementation Plan: Domain Layer II — Savings, Investments & Tax (Phase 4)

**Branch**: `005-savings-investments-tax` | **Date**: 2026-06-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/005-savings-investments-tax/spec.md`

> Incorporates the three `/speckit-clarify` Session 2026-06-30 passes (14 clarifications): FIFO tax-lot
> relief with a short-term/long-term split; trailing-3-month goal contribution rate; compute-both /
> flag-greater standard-vs-itemized (no auto-commit); dividends from `Investments/dividends.csv` +
> ledger interest; benchmark return = simple ≤1Y / CAGR 3Y–5Y with last-close-on-or-before anchoring;
> standard-deduction hardcoded table; savings progress = snapshot-anchored else ledger-derived;
> `archived` filtered, `completed` derived; **stored** (not derived) Investments/Savings estimated
> rate with a "rate not set" state; **computed** simplified tax estimate (projected liability +
> safe-harbor) with `estimates.csv` overrides; simplified ≈20% QBI.

## Summary

Build the remaining v1 domain engines on top of the merged Phase 2 parsing/validation pipeline and the
Phase 3 `AccountEngine` / `BudgetEngine` / `OverviewEngine` read model, and replace the two Phase 3
Overview stubs (Investments, Taxes) with live data. Phase 3 already created the model-stub files
(`Domain/Investments/InvestmentModels.swift`, `Domain/Savings/SavingsModels.swift`,
`Domain/Taxes/TaxModels.swift`) and the `Domain/Mapping/` seam; this phase fleshes them out and adds
the engines, fixtures, seed data, and CLIs.

- **Record-mapping extension** (`Domain/Mapping/`): `ParsedRecord` → `Asset`, `PricePoint`, `Trade`
  (the `type = trade` ledger rows), `Dividend`, `Portfolio`, `Sleeve`, `SleeveTarget`, `SavingsGoal`,
  `SavingsProgress`, `TaxAdjustment`, `TaxEstimate`, `TaxDocument`, `BenchmarkPoint`.
- **`SavingsGoalEngine`** (`Domain/Savings/`, read-only): snapshot-anchored-else-ledger progress,
  gap-to-target, months-to-goal at the trailing-3-month contribution rate, `GoalFundingLink`
  resolution; `archived` filtered, `completed` derived.
- **`PortfolioEngine`** (`Domain/Investments/`, read-only): `Portfolio → Sleeve → Asset` hierarchy,
  position value (`quantity × latest close`), cost basis, unrealized gain/loss, FIFO tax-lots from
  trade history, dividend totals, sleeve actual-vs-target weight + drift; aggregate + per-account.
- **`BenchmarkEngine`** (`Domain/Investments/`, read-only): S&P 500 series load, 8-period % growth
  (simple ≤1Y / CAGR 3Y–5Y) with calendar anchoring + last-close-on-or-before, heat-map data model,
  sector performance weights.
- **`TaxEngine`** (`Domain/Taxes/`, read-only): YTD taxable income per account, taxes paid, effective
  rate, realized gain/loss split ST/LT (FIFO), dividend/interest aggregation.
- **`TaxAdjustmentEngine`** (`Domain/Taxes/`): adjustment/estimate/document records; **standard-
  adjustment seeding** (a safe write); taxable-income-minus-adjustments incl. simplified ≈20% QBI;
  standard-vs-itemized compute-both/flag-greater; business-expense cross-reference with `AccountEngine`;
  **computed** simplified projected liability + safe-harbor with `estimates.csv` override.
- **`TaxPrepEngine`** (`Domain/Taxes/`): the fixed v1 prep checklist (W-2 / 1099s / estimated
  payments / deduction confirmations) classified complete/incomplete/missing; tax-relevant
  `ValidationIssue` surfacing; **`TaxArchiveYear` year-close** archive write (a safe write) + read-only
  enforcement thereafter.
- **CrossDomain completion** (`Domain/CrossDomain/`): extend `LinkingEngine` with portfolio-to-tax and
  Schedule C links; update `OverviewEngine` so the Investments and Taxes cards carry live values
  (stored estimated rate → "rate not set" when absent).
- **Seed/fixture data** (`WorkspaceLayout` + `fixture-generate`): a seeded standard tax-adjustment row,
  the hardcoded standard-deduction table, and fixtures for assets/prices/trades/dividends, a portfolio
  with sleeves/targets, an S&P 500 benchmark series, goals/progress, and tax estimates/documents.
- **Developer CLIs**: `savings-overview`, `portfolio-overview`, `benchmark-overview`, `tax-overview`
  — one per engine group, matching the Phase 3 `accounts-overview` / `budget-overview` /
  `overview-dashboard` pattern (and the updated `overview-dashboard` now shows all five live cards).

Technical approach: continue the SwiftPM package (Swift 6, value-type `Sendable` projections, no new
third-party dependencies). Engines are **pure functions of `WorkspaceContext` + an injected as-of date
+ `WorkspaceSettings`**, returning value-type projections — except the two stateful, user-confirmed
write actions (standard-adjustment seed, year-close archive), which route through the Phase 1 safe-
write primitives (`BackupService` + atomic apply + `WriteGate`). Files stay canonical; projections are
regenerable.

## Technical Context

**Language/Version**: Swift 6.
**Primary Dependencies**: Foundation (`Decimal`, `Calendar`/`Date`/`DateComponents` for period
anchoring); the merged Phase 2 `FinanceWorkspaceKit` parsing layer (`WorkspaceParser`,
`WorkspaceContext`, `ParsedRecord`/`FieldValue`/`TypedValue`); the Phase 2 `ValidationEngine` +
`RuleCatalog` (tax-relevant issue surfacing); the Phase 2 `SettingsStore`
(`WorkspaceSettings.filingStatus` / `taxYear`); the Phase 1 safe-write primitives (`BackupService`,
`FileCoordinatorService`, `WriteGate`) for the two write actions; the Phase 3 `AccountEngine` (business
account-group expense totals, ledger access) and `BudgetEngine` (goal contributions). The R6 JSON
schemas for every new file type already ship in `Resources/Schemas/` (assets, prices, dividends,
portfolios, sleeves, sleeve-targets, benchmark, goals, progress, tax-adjustments, tax-estimates,
tax-documents, tax-lots, estimated-payments). No new external dependencies.
**Storage**: Plain CSV + Markdown files (canonical, unchanged). Engines are read-only; the only writes
are the standard-adjustment seed (to `Taxes/tax-adjustments.csv`) and the year-close archive (to
`Taxes/archive/YYYY-*.csv`), both via the Phase 1 safe-write path. Seed content lives in
`WorkspaceLayout`.
**Testing**: Swift Testing (`import Testing`); fixture-driven against a local-folder workspace
(`fixture-generate` output + hand-authored small fixtures: a FIFO multi-lot buy/sell fixture spanning
the 1-year ST/LT boundary; a sparse / no-snapshot goal fixture; a benchmark series with weekend/holiday
gaps and a too-short-history period; a business-expense Schedule C fixture; a closed-year archive
fixture). Runs in macOS CI (`ci-macos.yml`); SwiftLint `--strict` on the Linux runner.
**Target Platform**: macOS 15 (Sequoia) or newer.
**Project Type**: Native macOS app delivered as a Swift Package — `FinanceWorkspaceKit` library +
`FinanceWorkspaceApp` and developer CLI executables (no `.xcodeproj` yet).
**Performance Goals**: build every new projection for a realistic 12-month workspace within a couple of
seconds on Apple Silicon (M1+). Hard thresholds and projection caching are Phase 7.
**Constraints**: offline-capable; files canonical (no hidden DB); projections regenerable and read-only
(FR-025/027) except the two named safe writes; deterministic under an injected as-of date; resilient to
sparse/empty/partially-invalid input — never crash, nil, or emit a misleading zero/value (typed
"price unavailable" / "insufficient history" / "rate not set" states per FR-009/013/024a); FIFO lot
relief is the locked accounting method (FR-006/016).
**Observability**: engines surface dangling/invalid references through the existing `ValidationEngine`
issue stream; `OverviewEngine` and `TaxPrepEngine` consume that stream (FR-019/021). Logging stays on
Phase 1 `os.Logger`; the two write actions log through `BackupService` / repair-log conventions.
**Scale/Scope**: single user, single workspace; 5 new engines (Savings, Portfolio, Benchmark, Tax,
TaxAdjustment+TaxPrep) + LinkingEngine/OverviewEngine completion + record-mapping extension + seed/
fixtures + 4 CLIs; ~11 projection model groups (fleshing out the Phase-1/3 stubs).

No open `NEEDS CLARIFICATION` — the eleven material ambiguities were resolved across three
`/speckit-clarify` passes (spec §Clarifications); remaining mechanisms are locked in
`docs/architecture/core-domain.md §3` and `docs/architecture/containers-and-budgets.md §3`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source:
`.specify/memory/constitution.md` v1.1.1.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; CSV/MD canonical; projections derived | ✅ PASS — engines read `WorkspaceContext` and return value-type projections; the two writes target canonical CSVs, no shadow DB |
| II. Read Model Second | Regenerable from files; one bad file doesn't block unrelated domains | ✅ PASS — pure functions of parsed input; per-file resilience inherited from Phase 2; partial/empty results return typed states, never crash (FR-025) |
| III. Native Over Generic | macOS-native; Finder-openable files | ✅ PASS — no UI this phase; files untouched and externally editable; archive files are plain CSV |
| IV. Safe Writes Only | Backup, atomic, sync-gated, manual conflict, repair log | ✅ PASS — the **two** writes (standard-adjustment seed FR-018, year-close archive FR-022) route through `BackupService` + atomic apply + `WriteGate`; no other write path is added |
| V. Traceability Always | Every value traces to source file + row | ✅ PASS — projections carry `source_file`/`source_row` provenance from `ParsedRecord`; realized-gain lots trace to their trade rows; KPI → detail composition preserved for Phase 5 |
| VI. Cross-Domain Visibility | `account_id` resolves to master registry; `LinkingEngine` connects domains | ✅ PASS — all engines resolve `account_id` against the Phase 3 `AccountEngine` registry; `LinkingEngine` gains portfolio-to-tax + Schedule C links (FR-023); Overview composes all five domains live (FR-024) |
| VII. Repair When Safe | Deterministic, previewable, classified repairs | ✅ PASS (N/A) — no new repair; dangling references surface via the existing validation stream; the standard-adjustment seed is a deterministic, previewable template write, not a speculative repair |
| File & Schema Conventions | `# schema_version` row; unified ledger; three-tier classification; `.finance-meta/` app-managed | ✅ PASS — trades read from the unified `Accounts/transactions/YYYY-MM.csv` ledger as `type = trade`; the seeded standard row and archive files keep the `# schema_version: N` comment row and existing R6 headers (no schema/version change — rows added, not columns) |
| V1 Scope Boundaries | No deferred-scope features; Tax module estimates only (not a filing engine) | ✅ PASS — all tax figures are estimates (simplified QBI, hardcoded standard deduction, computed safe-harbor); no filing engine, no live price/market data, no brokerage sync, no AI; UI deferred to Phase 5 |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts)**: PASS — the record-mapping extension reuses the
existing `Domain/Mapping/` seam (no new abstraction tier). The two safe writes reuse the Phase 1
primitives verbatim rather than introducing a new write subsystem, satisfying Principle IV without new
complexity. Keeping the estimated rate a *stored* read (not a derived calc) and the tax estimate a
*computed* projection both fall out of the spec clarifications and add no hidden state. No Complexity
Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/005-savings-investments-tax/
├── plan.md              # This file
├── research.md          # Phase 0 output — FIFO lots/ST-LT, period anchoring + CAGR, tax estimate math, two-write safety, CLI shape
├── data-model.md        # Phase 1 output — mapped entities + fleshed-out projection models
├── quickstart.md        # Phase 1 output — build, seed, run the four CLIs against a fixture
├── contracts/
│   ├── engine-contracts.md      # SavingsGoal / Portfolio / Benchmark / Tax / TaxAdjustment / TaxPrep + Linking/Overview surface
│   ├── record-mapping.md         # ParsedRecord → Asset/Trade/Dividend/Portfolio/Sleeve/Goal/Tax* mapping rules
│   ├── seed-data.md              # standard-deduction table + seeded standard adjustment + fixtures
│   └── cli-scripts.md            # savings-overview / portfolio-overview / benchmark-overview / tax-overview
├── checklists/requirements.md    # /speckit-specify output
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

Phase 4 touches the **bold**-noted folders; the rest already exist from Phase 1–3. The repo is a
**Swift Package**, not an `.xcodeproj`. Phase 3 already created the `Investments` / `Savings` / `Taxes`
model-stub files — Phase 4 extends them and adds the engines.

```text
Sources/
  FinanceWorkspaceKit/
    Parsing/               # Phase 2 (consumed, unchanged)
    Validation/            # Phase 2 (consumed; tax-relevant issue tagging read by TaxPrepEngine)
    Persistence/           # Phase 2 (consumed): SettingsStore → filingStatus / taxYear
    Platform/
      WorkspaceLayout.swift          # ← edited: seeded standard adjustment + standard-deduction table + new seed files
      (BackupService / FileCoordinatorService / WriteGate — Phase 1, reused for the two writes)
    Domain/
      Mapping/             # ← extended: new record mappers
        RecordMappers.swift          (+ Asset/PricePoint/Trade/Dividend/Portfolio/Sleeve/SleeveTarget/Goal/Progress/TaxAdjustment/TaxEstimate/TaxDocument/BenchmarkPoint)
        PeriodMath.swift             (+ calendar-anchored period lookup, last-close-on-or-before, CAGR helper)
      Savings/             # ← Phase 4
        SavingsModels.swift          (extend: GoalProgressProjection)
        SavingsGoalEngine.swift      (NEW)
      Investments/         # ← Phase 4
        InvestmentModels.swift       (extend: HoldingsProjection, SleeveAllocation, TaxLot, BenchmarkCell/heat-map model)
        PortfolioEngine.swift        (NEW)
        BenchmarkEngine.swift        (NEW)
      Taxes/               # ← Phase 4
        TaxModels.swift              (extend: RealizedGainSummary, TaxDeductionSummary, TaxPrepSummary, TaxEstimateProjection, TaxArchiveYear)
        TaxEngine.swift              (NEW)
        TaxAdjustmentEngine.swift    (NEW — incl. standard-adjustment seed via safe-write)
        TaxPrepEngine.swift          (NEW — incl. year-close archive via safe-write)
      CrossDomain/         # ← Phase 4 (completion)
        CrossDomainModels.swift      (extend: portfolio-to-tax + Schedule C link types; live Investments/Taxes card state)
        LinkingEngine.swift          (edited: add the two new link kinds)
        OverviewEngine.swift         (edited: consume real Portfolio/Benchmark/Tax projections; remove stubs)
  savings-overview/        # ← NEW executable target (CLI for SavingsGoalEngine)
  portfolio-overview/      # ← NEW executable target (CLI for PortfolioEngine + sleeves/drift)
  benchmark-overview/      # ← NEW executable target (CLI for BenchmarkEngine heat map)
  tax-overview/            # ← NEW executable target (CLI for Tax/TaxAdjustment/TaxPrep)
    main.swift
  overview-dashboard/      # ← edited: all five cards now live
  fixture-generate/        # ← edited: emit assets/prices/trades/dividends/portfolio/sleeves/sp500/goals/tax fixtures
Tests/
  FinanceWorkspaceKitTests/
    Unit/
      SavingsGoalEngineTests.swift   # ← NEW (US5)
      PortfolioEngineTests.swift     # ← NEW (US1 — FIFO lots, drift, price-unavailable)
      BenchmarkEngineTests.swift     # ← NEW (US4 — 8 periods, CAGR, anchoring, insufficient-history)
      TaxEngineTests.swift           # ← NEW (US2 — taxable income, ST/LT realized gains, effective rate)
      TaxAdjustmentEngineTests.swift # ← NEW (US3 — seed, standard-vs-itemized, QBI, business x-ref, estimate)
      TaxPrepEngineTests.swift       # ← NEW (US3 — checklist states, year-close archive read-only)
      OverviewEngineTests.swift      # ← edited (US6 — live Investments/Taxes cards, "rate not set")
      LinkingEngineTests.swift       # ← edited (US6 — portfolio-to-tax, Schedule C links)
      RecordMappersTests.swift       # ← edited (new entity mappings)
      SeedDataTests.swift            # ← edited (standard adjustment + new seed files validate clean)
    Fixtures/              # ← FIFO multi-lot, no-snapshot goal, gap/short benchmark, Schedule C, closed-year
Package.swift              # ← edited: 4 new executable targets
```

**Structure Decision**: Single Swift Package, extending the existing
`Sources/FinanceWorkspaceKit/Domain/**` tree. Engines are added as new files beside the Phase-3
model-stub files they flesh out; the existing `Domain/Mapping/` seam is extended (not duplicated) so
every engine shares one typed input. The two stateful writes reuse the Phase 1 safe-write primitives.
Four new executable targets mirror the established CLI pattern. No new module or external dependency is
introduced.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
