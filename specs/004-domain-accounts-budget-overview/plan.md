# Implementation Plan: Domain Layer I — Accounts, Budget & Overview (Phase 3)

**Branch**: `004-domain-accounts-budget-overview` | **Date**: 2026-06-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/004-domain-accounts-budget-overview/spec.md`

> Incorporates the `/speckit-clarify` Session 2026-06-30 answers: YTD anchored to the workspace
> `tax_year`; `taxes_paid` is ledger-derived (withholding legs) only; "current period" is an
> injectable as-of-date month; the Overview Savings card is `AccountEngine`-derived over
> `account_group = savings` accounts.

## Summary

Build the first domain (read-model) layer on top of the merged Phase 2 parsing/validation pipeline.
The Phase 2 `WorkspaceParser` already produces a `WorkspaceContext` of typed-but-generic
`ParsedRecord`s; this phase turns those into **typed domain entities** and then into **projections**:

- A thin **record-mapping** layer (`ParsedRecord` → `Account`, `AccountGroup`, `Liability`,
  `AccountRule`/`AccountEstimate`, `UnifiedTransaction`, `Category`, `Budget`, `BudgetAllocation`,
  `SavingsGoal`) — the missing seam between Phase 2's generic records and the Phase 1 domain structs.
- **`AccountEngine`** (built first, read-only): aggregate + per-group + per-account projections,
  ledger-derived balances and `Liability.principal_balance`, YTD net income (tax-year-anchored,
  transfers excluded, `taxes_paid` from withholding legs), account-rule/estimate cash-flow projection
  for empty current months, multi-entry group resolution, multi-employment-group aggregation.
- **`BudgetEngine`**: monthly totals, plan-vs-actual variance over a budget's allocations and scope,
  3-month trailing average with a partial-confidence flag, spend-mix percentages, savings-goal
  contributions surfaced as a budget output.
- **`LinkingEngine`** + **`OverviewEngine`**: goal- and sleeve-funding links; the five KPI cards
  (Budget/Savings/Business live; Investments/Taxes return the typed "data not available" state);
  the trailing-6-month, gap-skipping month-over-month panel; aggregated validation issues.
- **Seed data**: the canonical `account_type` taxonomy applied to the six locked seed accounts, and
  an expanded default `Budget/categories.csv` set across six category groups, in `WorkspaceLayout`.
- **Developer CLIs**: `accounts-overview`, `budget-overview`, `overview-dashboard` — one per engine,
  matching the existing `validate-workspace` / `index-check` CLI pattern.

Technical approach: continue the Phase 1/2 SwiftPM package (Swift 6, value-type projections, no new
third-party dependencies). Engines are **pure functions of `WorkspaceContext` + an injected as-of
date + `WorkspaceSettings`**, returning `Sendable` value-type projections. Files stay canonical; every
projection is regenerable and the engines never write. This phase ships no end-user UI — it delivers
the read model plus CLIs, exactly as Phase 2 shipped the parse pipeline plus CLIs.

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: Foundation (`Decimal`, `Calendar`/`Date`, `DateComponents`); the merged
Phase 2 `FinanceWorkspaceKit` parsing layer (`WorkspaceParser`, `WorkspaceContext`, `CSVParseResult`/
`ParsedRecord`/`FieldValue`/`TypedValue`); the Phase 2 `ValidationEngine` + `RuleCatalog` (for the
Overview issue list); the Phase 2 `SettingsStore` (`WorkspaceSettings.taxYear`); the Phase 1 domain
model structs in `Domain/**`. No new external dependencies.
**Storage**: Plain CSV + Markdown files (canonical, unchanged). Engines are read-only — **no writes**.
Seed content lives in `WorkspaceLayout` (already the single source for bootstrap seeds).
**Testing**: Swift Testing (`import Testing`); fixture-driven against a local-folder workspace
(`fixture-generate` output + hand-authored small fixtures: a multi-employment fixture, a sparse
<3-month fixture, a gap-month fixture, a paycheck-split + transfer fixture). Runs in macOS CI
(`ci-macos.yml`); SwiftLint `--strict` on the Linux runner.
**Target Platform**: macOS 15 (Sequoia) or newer.
**Project Type**: Native macOS app delivered as a Swift Package — `FinanceWorkspaceKit` library +
`FinanceWorkspaceApp` and developer CLI executables (no `.xcodeproj` yet).
**Performance Goals**: build all three projections for a realistic 12-month workspace within a couple
of seconds on Apple Silicon (M1+). Hard thresholds and projection caching are Phase 7.
**Constraints**: offline-capable; files canonical (no hidden DB); projections regenerable and
**read-only** (FR-025); deterministic under an injected as-of date (FR-001/006); resilient to sparse/
empty/partially-invalid input — never crash, nil, or emit a misleading zero (FR-023); `AccountEngine`
exposes read-only projection interfaces only and does not absorb Tax/Investment logic (FR-009).
**Observability**: engines surface dangling/invalid references through the existing
`ValidationEngine` issue stream (not new error channels); `OverviewEngine` aggregates that stream for
the issues list (FR-019). Foundation-level logging stays on Phase 1 `os.Logger`.
**Scale/Scope**: single user, single workspace; 4 engines (3 domain + linking) + a record-mapping
layer + seed data + 3 CLIs; ~9 projection model groups (fleshing out the Phase-1 stubs).

No open `NEEDS CLARIFICATION` — the four material ambiguities were resolved in the spec's
`/speckit-clarify` Session 2026-06-30; the remaining mechanisms are locked in
`docs/architecture/core-domain.md §3` and `docs/architecture/containers-and-budgets.md §3`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source:
`.specify/memory/constitution.md` v1.1.1.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; CSV/MD canonical; projections derived | ✅ PASS — engines read `WorkspaceContext` and return value-type projections; nothing persisted |
| II. Read Model Second | Regenerable from files; one bad file doesn't block unrelated domains | ✅ PASS — pure functions of parsed input; per-file resilience inherited from Phase 2; partial/empty results never crash (FR-023) |
| III. Native Over Generic | macOS-native; Finder-openable files | ✅ PASS — no UI this phase; files untouched and externally editable |
| IV. Safe Writes Only | Backup, atomic, sync-gated, manual conflict, repair log | ✅ PASS (N/A) — phase is strictly read-only (FR-025); no write path is added |
| V. Traceability Always | Every value traces to source file + row | ✅ PASS — projections carry through `source_file`/`source_row` provenance from `ParsedRecord`; KPI → detail composition preserved for Phase 5 |
| VI. Cross-Domain Visibility | `account_id` resolves to master registry; `LinkingEngine` connects domains | ✅ PASS — `AccountEngine` is the master read model; `LinkingEngine` builds goal/sleeve links (FR-015); Overview composes all domains (FR-016) |
| VII. Repair When Safe | Deterministic, previewable, classified repairs | ✅ PASS (N/A) — no repair added; dangling references are surfaced via the existing validation stream, not auto-fixed |
| File & Schema Conventions | `# schema_version` row; unified ledger; three-tier classification; `.finance-meta/` app-managed | ✅ PASS — engines consume the unified `Accounts/transactions/YYYY-MM.csv` ledger; seed expansion keeps the `# schema_version: 1` comment row and existing headers (no schema/version change — category *rows* added, not columns) |
| V1 Scope Boundaries | No deferred-scope features; Business is an account-group type within Accounts | ✅ PASS — Business P&L lives in `AccountEngine` (no `BusinessEngine`); Savings/Portfolio/Tax engines explicitly deferred to Phase 4; no AI, no sync, no rules automation |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts)**: PASS — the record-mapping layer is a thin
adapter (generic `ParsedRecord` → existing typed structs), not a new abstraction tier or data store;
it reduces duplication by giving all four engines one typed input instead of each re-reading raw
fields. Injecting the as-of date (rather than reading the clock inside engines) keeps engines pure and
testable, reinforcing Principle II. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/004-domain-accounts-budget-overview/
├── plan.md              # This file
├── research.md          # Phase 0 output — record mapping, as-of injection, YTD/taxes math, CLI shape
├── data-model.md        # Phase 1 output — mapped entities + fleshed-out projection models
├── quickstart.md        # Phase 1 output — build, seed, run the three CLIs against a fixture
├── contracts/
│   ├── engine-contracts.md     # AccountEngine / BudgetEngine / LinkingEngine / OverviewEngine surface
│   ├── record-mapping.md        # ParsedRecord → typed domain entity mapping rules
│   ├── seed-data.md             # account_type taxonomy + default category set
│   └── cli-scripts.md           # accounts-overview / budget-overview / overview-dashboard
├── checklists/requirements.md   # /speckit-specify output
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

Phase 3 touches the **bold** folders; the rest already exist from Phase 1/2
(`docs/architecture/core-domain.md §2`). The repo is a **Swift Package**, not an `.xcodeproj`.

```text
Sources/
  FinanceWorkspaceKit/
    Parsing/               # Phase 2 (consumed, unchanged): WorkspaceParser, ParsedRecord, …
    Validation/            # Phase 2 (consumed, unchanged): ValidationEngine, RuleCatalog
    Persistence/           # Phase 2 (consumed, unchanged): SettingsStore → WorkspaceSettings
    Platform/
      WorkspaceLayout.swift          # ← edited: expanded category seed + canonical account_type seed
    Domain/
      Mapping/             # ← NEW: the ParsedRecord → typed-entity seam
        RecordMappers.swift          (Account/Group/Liability/Rule/Transaction/Category/Budget/Goal)
        AccountTypeTaxonomy.swift     (canonical account_type values per account_group)
      Accounts/            # ← Phase 3 core (built FIRST)
        AccountModels.swift           (extend: AccountDetailProjection, AccountGroupProjection, AccountsOverview)
        AccountEngine.swift           (NEW)
      Budget/              # ← Phase 3
        BudgetModels.swift            (extend: BudgetVarianceRow, TrailingAverage, BudgetMonthProjection, BudgetOverviewProjection)
        BudgetEngine.swift            (NEW)
      CrossDomain/         # ← Phase 3
        CrossDomainModels.swift       (extend: OverviewSummaryCard state, MonthlySnapshot, links)
        LinkingEngine.swift           (NEW)
        OverviewEngine.swift          (NEW)
  accounts-overview/       # ← NEW executable target (CLI for AccountEngine)
    main.swift
  budget-overview/         # ← NEW executable target (CLI for BudgetEngine)
    main.swift
  overview-dashboard/      # ← NEW executable target (CLI for OverviewEngine)
    main.swift
Tests/
  FinanceWorkspaceKitTests/
    Unit/
      AccountEngineTests.swift        # ← NEW (US1)
      BudgetEngineTests.swift         # ← NEW (US2)
      OverviewEngineTests.swift       # ← NEW (US3)
      LinkingEngineTests.swift        # ← NEW (US3)
      RecordMappersTests.swift        # ← NEW (mapping seam)
      SeedDataTests.swift             # ← NEW (US4 — taxonomy + category seed validate clean)
    Fixtures/              # ← small hand-authored fixtures (sparse, gap-month, multi-employment, paycheck-split)
Package.swift              # ← edited: 3 new executable targets
```

**Structure Decision**: Single Swift Package, extending the existing
`Sources/FinanceWorkspaceKit/Domain/**` tree. Engines are added as new files beside the Phase-1 model
stubs they flesh out; a new `Domain/Mapping/` folder holds the generic-record → typed-entity seam so
all engines share one typed input. Three new executable targets mirror the established CLI pattern
(`validate-workspace`, `index-check`). No new module or external dependency is introduced.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
</content>
