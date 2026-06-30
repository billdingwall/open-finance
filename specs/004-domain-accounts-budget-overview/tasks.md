---
description: "Task list — Domain Layer I: Accounts, Budget & Overview (Phase 3)"
---

# Tasks: Domain Layer I — Accounts, Budget & Overview

**Input**: Design documents from `specs/004-domain-accounts-budget-overview/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: INCLUDED — the spec's per-story Independent Tests and Success Criteria are fixture/CLI
driven, and the repo runs `swift test` in `ci-macos.yml` (consistent with Phase 2). Each story ships
its own tests.

**Organization**: Tasks are grouped by user story. Build order is enforced by the constitution's
master-registry rule: **US1 (AccountEngine) before US2/US4 before US3**.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1 / US2 / US3 / US4 (Setup/Foundational/Polish carry no story label)

## Path Conventions

Swift Package at repo root. Library code under `Sources/FinanceWorkspaceKit/`; CLI executables under
`Sources/<target>/`; tests under `Tests/FinanceWorkspaceKitTests/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the new folders, CLI targets, and a clean build before any logic lands.

- [ ] T001 [P] Create source folders: `Sources/FinanceWorkspaceKit/Domain/Mapping/`, `Sources/accounts-overview/`, `Sources/budget-overview/`, `Sources/overview-dashboard/`, `Tests/FinanceWorkspaceKitTests/Fixtures/`
- [ ] T002 Register three `.executableTarget`s (`accounts-overview`, `budget-overview`, `overview-dashboard`) depending on `FinanceWorkspaceKit` in `Package.swift`, each with a stub `main.swift` that prints usage and exits 2, so the package builds
- [ ] T003 [P] Confirm `swift build` and `swiftlint --strict` are green on the scaffold

**Checkpoint**: Package builds with empty CLI targets; folders exist.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `ParsedRecord` → typed-entity seam, the canonical taxonomy, and the shared
period/date math every engine depends on. ⚠️ No engine work can start until this phase is complete.

- [ ] T004 [P] Add `AccountTypeTaxonomy` (`[AccountGroupClass: [String]]` canonical map) in `Sources/FinanceWorkspaceKit/Domain/Mapping/AccountTypeTaxonomy.swift` per `contracts/seed-data.md §1`
- [ ] T005 Extend `AccountRule` (or add `AccountRuleDetail`) to carry `ruleType`/`amount`/`frequency`/`isActive` in `Sources/FinanceWorkspaceKit/Domain/Accounts/AccountModels.swift`, keeping existing callers compiling (per `contracts/record-mapping.md` note)
- [ ] T006 Implement `RecordMappers` (all 9 mappers: account, accountGroup, liability, accountRule, transaction, category, budget, budgetAllocation, savingsGoal) reading from `FieldValue.typed`, returning `nil` on missing/invalid required fields, in `Sources/FinanceWorkspaceKit/Domain/Mapping/RecordMappers.swift` per `contracts/record-mapping.md`
- [ ] T007 Add `WorkspaceContext` convenience accessors (`accounts`, `accountGroups`, `liabilities`, `accountRules`, `transactions`, `categories`, `budgets`, `budgetAllocations`, `savingsGoals`) as an extension in `Sources/FinanceWorkspaceKit/Domain/Mapping/RecordMappers.swift`, preserving record/file order (research R5/R11)
- [ ] T008 [P] Add `PeriodMath` helpers (as-of month string, YTD window `[Jan 1 taxYear … end of asOf month]`, trailing-N-month list) in `Sources/FinanceWorkspaceKit/Domain/Mapping/PeriodMath.swift` per research R2/R3/R9
- [ ] T009 [P] Add `RecordMappersTests` (typed reads, nil-on-invalid-required, optional→nil, provenance carried) in `Tests/FinanceWorkspaceKitTests/Unit/RecordMappersTests.swift`

**Checkpoint**: Engines can consume typed entities + period math from any `WorkspaceContext`.

---

## Phase 3: User Story 1 — Accounts read model (Priority: P1) 🎯 MVP

**Goal**: `AccountEngine` produces aggregate, per-group, and per-account projections from real files:
ledger-derived balances/liability principal, tax-year YTD net income with transfers excluded and
`taxes_paid` from withholding legs, rule-projected empty months, multi-entry resolution, multi-
employment aggregation.

**Independent Test**: `swift run accounts-overview --workspace <fixture> --as-of <date>` — balances
reconcile to the ledger, transfers are income/expense-neutral, business P&L matches hand calcs, an
account with a rule but no current-month txns shows `[projected]`.

- [ ] T010 [P] [US1] Extend account projection models (`AccountsOverview`, `AccountSummaryCard` fields, `AccountGroupProjection`, `AccountDetailProjection`, `AccountMonthFigures`) in `Sources/FinanceWorkspaceKit/Domain/Accounts/AccountModels.swift` per `data-model.md §B`
- [ ] T011 [US1] Implement multi-entry group resolution + transfer exclusion (groups net to zero; paycheck gross/withholding/net handling without double-counting) as a private helper in `Sources/FinanceWorkspaceKit/Domain/Accounts/AccountEngine.swift` per research R5
- [ ] T012 [US1] Implement ledger-derived `current_balance` and `Liability.principal_balance` in `AccountEngine` per research R6 / FR-004
- [ ] T013 [US1] Implement per-account/per-group YTD net income (`gross − expenses − taxesPaid`, tax-year window, withholding-leg `taxesPaid`, per-group term mapping) in `AccountEngine` per FR-005 / research R3-R4
- [ ] T014 [US1] Implement account-rule/estimate cash-flow projection for accounts with no as-of-month transactions (`isProjected = true`) in `AccountEngine` per FR-006
- [ ] T015 [US1] Implement `AccountEngine.overview` / `detail(for:)` / `groupDetail(for:)` (business P&L for business groups; multi-employment aggregation) in `AccountEngine` per `contracts/engine-contracts.md` / FR-001/002/003/008
- [ ] T016 [US1] Wire the `accounts-overview` CLI (`--workspace`, `--as-of`; parse → settings → engine → print) in `Sources/accounts-overview/main.swift` per `contracts/cli-scripts.md`
- [ ] T017 [P] [US1] Add `AccountEngineTests` against fixtures (multi-employment, paycheck-split+transfer, empty-current-month, business group) asserting SC-002/SC-003/SC-008 in `Tests/FinanceWorkspaceKitTests/Unit/AccountEngineTests.swift`
- [ ] T018 [P] [US1] Add the supporting hand-authored fixtures under `Tests/FinanceWorkspaceKitTests/Fixtures/` (multi-employment, paycheck+transfer, sparse, gap-month — shared with later stories)

**Checkpoint**: US1 independently verifiable via the CLI and `swift test`. **MVP reached.**

---

## Phase 4: User Story 2 — Budget plan-vs-actual with trailing averages (Priority: P2)

**Goal**: `BudgetEngine` computes monthly totals, per-category plan-vs-actual over a budget's resolved
scope, the partial-aware 3-month trailing average, spend-mix percentages, and goal contributions.

**Independent Test**: `swift run budget-overview --workspace <fixture> --period <ym>` — variance per
category, a `<3-month` category shows `avg of N mo` (never 0), spend-mix sums correctly, goal rows
appear for tagged transactions.

- [ ] T019 [P] [US2] Extend budget projection models (`BudgetOverviewProjection`, `BudgetVarianceRow`, `TrailingAverage`, `SpendMix`, `BudgetTotals`, `GoalContributionRow`) in `Sources/FinanceWorkspaceKit/Domain/Budget/BudgetModels.swift` per `data-model.md §C`
- [ ] T020 [US2] Implement monthly totals (income/fixed/discretionary/transfers/savings/investments + net monthly income, transfers excluded) in `Sources/FinanceWorkspaceKit/Domain/Budget/BudgetEngine.swift` per FR-010
- [ ] T021 [US2] Implement budget-scope resolution (`accountGroupIds` ∪ `accountIds`) and per-category plan-vs-actual variance in `BudgetEngine` per FR-011
- [ ] T022 [US2] Implement `trailingAverage(categoryId:endingBefore:)` returning `(value, monthsAvailable, isPartial)`, partial <3 months, never zero/blank for ≥1 month, in `BudgetEngine` per FR-012 / research R7
- [ ] T023 [US2] Implement spend-mix percentages and goal-contribution rows (`savings_goal_id`-tagged) in `BudgetEngine.overview` per FR-013/FR-014
- [ ] T024 [US2] Wire the `budget-overview` CLI (`--workspace`, `--budget`, `--period`, `--as-of`) in `Sources/budget-overview/main.swift` per `contracts/cli-scripts.md`
- [ ] T025 [P] [US2] Add `BudgetEngineTests` (sparse <3-month fixture for SC-004, spend-mix, scope resolution, goal contributions) in `Tests/FinanceWorkspaceKitTests/Unit/BudgetEngineTests.swift`

**Checkpoint**: US2 verifiable independently; US1 still passes.

---

## Phase 5: User Story 4 — Realistic starter workspace (Priority: P2)

**Goal**: Bootstrap seeds the expanded default category set (six groups) and canonical seed-account
`account_type` values; a fresh workspace validates clean and yields non-empty projections.

**Independent Test**: bootstrap a fresh workspace → `validate-workspace` reports zero errors; seeded
categories cover six groups; every seed `account_type` ∈ taxonomy.

- [ ] T026 [US4] Expand the `Budget/categories.csv` seed to the 16-row, six-group set and correct the six seed accounts' `account_type` values in `Sources/FinanceWorkspaceKit/Platform/WorkspaceLayout.swift` per `contracts/seed-data.md §1-2`
- [ ] T027 [P] [US4] Add `SeedDataTests` (every seed `account_type` ∈ `AccountTypeTaxonomy` for its group; categories cover six groups; bootstrapped workspace validates with zero errors — SC-007) in `Tests/FinanceWorkspaceKitTests/Unit/SeedDataTests.swift`

**Checkpoint**: Fresh bootstrap validates clean across six category groups.

---

## Phase 6: User Story 3 — Composed Overview dashboard data (Priority: P3)

**Goal**: `LinkingEngine` builds goal/sleeve links; `OverviewEngine` composes the five KPI cards
(Budget/Savings/Business live, Investments/Taxes `data not available`), the trailing-6-month gap-
skipping MoM panel, and the aggregated validation issues.

**Independent Test**: `swift run overview-dashboard --workspace <fixture> --as-of <date>` — three live
cards, two `data not available`, MoM skips empty months, issue summary mirrors `validate-workspace`.

- [ ] T028 [P] [US3] Extend cross-domain models (`OverviewDashboard`, `OverviewSummaryCard` fields/state, populate `MonthlySnapshot`, `GoalFundingLink`/`SleeveFundingLink`) in `Sources/FinanceWorkspaceKit/Domain/CrossDomain/CrossDomainModels.swift` per `data-model.md §D`
- [ ] T029 [US3] Implement `LinkingEngine.goalLinks` / `sleeveLinks` from the unified ledger in `Sources/FinanceWorkspaceKit/Domain/CrossDomain/LinkingEngine.swift` per FR-015
- [ ] T030 [US3] Implement the Savings + Business cards from `AccountEngine` (savings-group balance/inflow; business-group P&L) and the Budget card from `BudgetEngine` in `Sources/FinanceWorkspaceKit/Domain/CrossDomain/OverviewEngine.swift` per FR-017 / research R8
- [ ] T031 [US3] Implement the typed `dataNotAvailable` Investments + Taxes cards and assemble all five cards in `OverviewEngine.dashboard` per FR-016/FR-017
- [ ] T032 [US3] Implement the trailing-6-month, gap-skipping month-over-month panel and the aggregated `ValidationEngine` issue list in `OverviewEngine` per FR-018/FR-019 / research R9
- [ ] T033 [US3] Wire the `overview-dashboard` CLI (`--workspace`, `--as-of`) in `Sources/overview-dashboard/main.swift` per `contracts/cli-scripts.md`
- [ ] T034 [P] [US3] Add `LinkingEngineTests` and `OverviewEngineTests` (gap-month fixture for SC-006; stub-card assertions for SC-005; issue aggregation) in `Tests/FinanceWorkspaceKitTests/Unit/OverviewEngineTests.swift`

**Checkpoint**: Full Overview composes; all four engines green together.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Read-only guarantee, docs, and the Milestone 3 gate.

- [ ] T035 [P] Add a read-only guarantee test: a full projection run leaves workspace bytes unchanged (hash before/after) — SC-009 — in `Tests/FinanceWorkspaceKitTests/Unit/ReadOnlyGuaranteeTests.swift`
- [ ] T036 [P] Add the three new `swift run …` lines to the Build & test block in `CLAUDE.md`
- [ ] T037 [P] Apply [FIX-C2]: correct the Phase 3 critical-dependency note (master registry `Accounts/accounts.csv`; account-groups via `Accounts/account-groups.csv`; remove `Investments/accounts.csv` / `Business/entities.csv`) in `docs/product-roadmap.md` and mark `[FIX-C2]` resolved in `docs/project-management.md`
- [ ] T038 [P] Doc cascade per CLAUDE.md spec-completion workflow: update `docs/out-of-scope-followups.md` (any Phase-3 items deferred during implementation) and `docs/test-plans.md` (engines now testable via the three CLIs)
- [ ] T039 Final `swift build` + `swiftlint --strict` + `swift test` pass; confirm the Milestone 3 gate (accounts aggregate+per-account, budget plan-vs-actual with trailing averages, Overview composed with stubs, cross-domain links live) per `docs/product-roadmap.md`

---

## Dependencies & Execution Order

```
Phase 1 (Setup)            → T001 → T002 → T003
Phase 2 (Foundational)     → T004,T008,T009 [P]; T005 → T006 → T007   (BLOCKS all stories)
Phase 3 (US1, P1) 🎯       → T010 → T011 → T012 → T013 → T014 → T015 → T016; T017,T018 [P]
Phase 4 (US2, P2)          → T019 → T020 → T021 → T022 → T023 → T024; T025 [P]   (needs Foundational; ledger access shared with US1 but independent)
Phase 5 (US4, P2)          → T026 → T027   (needs T004 taxonomy; otherwise independent — can run alongside US2)
Phase 6 (US3, P3)          → T028 → T029 → T030 → T031 → T032 → T033; T034 [P]   (needs US1 + US2 engines)
Phase 7 (Polish)           → T035-T038 [P]; T039 last
```

- **US1 → US2/US4 → US3** is the hard ordering (US3's Overview consumes US1+US2 engines; the
  constitution mandates AccountEngine first).
- **US2 and US4 are independent** of each other and can be built in parallel after Foundational.
- Foundational (T004-T009) blocks everything; do not start US tasks until T003-T007 land.

## Parallel Execution Examples

- **Foundational kick-off**: T004, T008, T009 in parallel (distinct files), then T005→T006→T007.
- **Within US1**: T017 and T018 (tests + fixtures) parallel with each other once T010-T016 land;
  T010 parallel-safe at the start (model file) before the engine logic tasks.
- **Across stories after Foundational**: one developer on US2 (T019-T025), another on US4
  (T026-T027) simultaneously.
- **Polish**: T035, T036, T037, T038 all parallel (different files); T039 gates last.

## Implementation Strategy

- **MVP = Phase 1 + Phase 2 + Phase 3 (US1)** — a verifiable Accounts read model and the master
  registry every later engine depends on. Ship/checkpoint here.
- **Increment 2**: US2 (Budget) + US4 (Seed) in parallel — the primary personal-finance view plus a
  realistic starter workspace.
- **Increment 3**: US3 (Overview/Linking) — cross-domain composition proving the stub contract.
- **Close-out**: Phase 7 — read-only proof, doc cascade ([FIX-C2] + the two living docs), Milestone 3
  gate.

## Task Summary

- **Total**: 39 tasks (T001-T039)
- **By story**: Setup 3 · Foundational 6 · US1 9 · US2 7 · US4 2 · US3 7 · Polish 5
- **Parallel-marked [P]**: 17 tasks
- **Tests**: 6 test tasks (RecordMappers, AccountEngine, BudgetEngine, SeedData, Overview/Linking,
  ReadOnlyGuarantee) — one per story plus the foundational seam and the read-only proof
- **Suggested MVP**: T001-T018 (through US1)
</content>
