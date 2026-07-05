# Data Model — Presentation Layer (006)

Presentation-layer models only. Domain projections (Phases 3–4) are consumed as-is; nothing here
is persisted — every model is derived per session (constitution P-I/II).

## Navigation & shell state

### Route (enum, `AppRouter.swift`)

The single typed description of "where the user is". Serialized by `RouteActivityCodec` (D6).

| Case | Payload | Notes |
|---|---|---|
| `.overview` | — | default on launch; sidebar header target |
| `.accounts` | — | all-accounts card grid |
| `.accountGroup` | `accountGroupID: String` | group screen |
| `.account` | `accountID: String` | per-account screen |
| `.budget` | `BudgetSubview` (`overview` / `history` / `categories`) | |
| `.savingsInvestments` | `SISubview` (`overview` / `goals` / `portfolio`) | |
| `.goal` | `goalID: String` | goal detail |
| `.holding` | `assetID: String` | holding detail |
| `.taxes` | `TaxSubview` (`currentYear` / `prepChecklist` / `archive`) | |

- Validation: entity IDs are resolved against the current `WorkspaceProjections`; a stale ID
  (restored route for a deleted entity) falls back to the parent module route, never crashes.
- KPI navigation: `OverviewSummaryCard.id → Route` mapping (budget→`.budget(.overview)`, etc.).

### AppState (`@Observable`, main-actor)

Extends the existing Phase-1 object (provider/`WorkspaceManager` wiring, availability, sync state,
migration flag are kept as-is).

| Field | Type | Notes |
|---|---|---|
| existing | provider, availability, syncState, workspaceURL, didProvision, missingPaths, needsR6Migration, lastError | unchanged |
| `phase` | `LoadPhase` (`idle` / `indexing` / `ready` / `failed`) | drives skeletons + sync chip |
| `projections` | `WorkspaceProjections?` | atomic snapshot (D3) |
| `route` | `Route` | current selection; `.overview` initial |
| `sidebarExpansion` | `Set<SidebarGroupID>` | session-only |
| `detailPane` | `DetailPaneState` | see below |
| `sessionSelections` | `SessionSelections` | session-only selectors (per clarify Q1) |

`SessionSelections`: `budgetPeriod: YearMonth?`, `budgetHistoryRange`, `portfolioAccountID?`,
`portfolioViewMode (standard/heatMap)`, `taxYear: Int?` — all nil ⇒ "current/all"; reset on
relaunch (not encoded in the activity payload).

### DetailPaneState

`isPresented: Bool` (closed by default) + `surface: DetailPaneSurface?`.

### DetailPaneSurface (enum)

| Case | Payload | Producing interaction |
|---|---|---|
| `.inspector` | `SourceRef` | row traceability target |
| `.sourceFilePreview` | file URL + parsed header info | "Open Source File" context |
| `.sourceRowDetail` | `SourceRef` + raw field pairs | inspector drill |
| `.issueDetail` | `ValidationIssue` | issues table row |
| `.repairPreview` | `RepairPreview` (dry-run output) | "Preview Repair" |
| `.editForm` | entity ref | **unreachable in Phase 5** (actions disabled); surface type exists for Phase 6 |

### WorkspaceProjections (immutable snapshot, D3)

Built off-main by `ProjectionStore`; swapped whole.

- `builtAt: Date`, `asOf: Date`
- `dashboard: OverviewDashboard` (existing engine output — 5 cards, MoM, issues)
- `accounts: AccountEngine` aggregate/group/account projections
- `budget: BudgetEngine` projections (per selected period, computed via engine on demand from the
  snapshot's `WorkspaceContext` where a selector changes — the context is retained in the snapshot)
- `savings`, `portfolio`, `benchmark`, `tax*` projections
- `issues: [ValidationIssue]` (chip count + table)
- `context: WorkspaceContext` (for selector-driven engine re-runs; still read-only, still one
  consistent parse)

## Traceability & provenance

### SourceRef

`filePath` (workspace-relative), `rowNumber: Int`, `lastModified: Date?`,
`rawFields: [(name: String, value: String)]`, `provenance: Provenance`.

### Provenance (enum)

`imported` / `derived` / `repaired` / `userEdited` — rendered by `ValueProvenanceLabel`
(constitution P-II clause). Derived summary rows (e.g. grouped ledger entries, D7) are always
`derived`.

## Component contracts (shared vocabulary)

| Model | Fields | Consumed by |
|---|---|---|
| `KPICardModel` | id, overline, value (formatted, tabular), secondary, `Delta` (pos/neg/flat + text), `Route` tap target, `typedState?` ("rate not set" etc.) | `KPICardView` |
| `TableColumn spec` | id, title, alignment, sortable, width hints | `DataTableView` |
| `TableRowModel` | id, cells, `SourceRef?`, selectable | `DataTableView` |
| `PieSlice` | label, value, share | `PieChartView` (SectorMark) |
| `SparkPoint` | period, value | `SparklineView` (LineMark) |
| `HeatMapModel` | rows (account/benchmark/sector), 8 `HeatCell`s each: value?, `typedState?`, scale position | `HeatMapTableView` (Grid, D4) |
| `PeriodSelection` | granularity (month/quarter/year), current, prev/next availability | `PeriodSelectorView` |
| `EmptyStateModel` | glyph, title, message, optional CTA (disabled in Phase 5 where write-gated) | `EmptyStateView` |
| `LedgerEntry` | summary row + `legs: [TableRowModel]`, expanded flag (D7) | `LedgerTableView` |

## Module view models (projection → contract mappers)

One thin `@Observable`/pure mapper per module; **no finance math** — formatting, grouping, and
typed-state translation only (FR-031). Each is unit-tested (D8).

| View model | Input (engine) | Output |
|---|---|---|
| `OverviewViewModel` | `OverviewDashboard` | 5 `KPICardModel`s, MoM `SparkPoint`s, issues table rows (severity groups, repairable badge) |
| `AccountsViewModel` | AccountEngine projections | aggregate header (assets/liabilities), group sections, account cards, group/account screens' tables + chart series, `LedgerEntry` grouping, rules panel rows |
| `BudgetViewModel` | BudgetEngine (per session period) | pie slices, spend-mix + variance panel models, category table rows, drill-down filter |
| `SavingsInvestmentsViewModel` | SavingsGoal/Portfolio/Benchmark engines | goal cards + detail, holdings rows (typed price states), allocation donut, sleeve table, `HeatMapModel`, sector section, holding detail (lots/trades/dividends) |
| `TaxesViewModel` | Tax/TaxAdjustment/TaxPrep engines | current-year sections, deductions (both totals + recommended flag), checklist items (state + source link), archive years (read-only rows) |

## State transitions

- `LoadPhase`: `idle → indexing → ready` (snapshot swap) or `→ failed` (lastError surfaced);
  `ready → indexing` on Reindex, previous snapshot stays visible until the new one swaps (FR-036).
- `DetailPaneState`: closed →(row selection)→ open(surface); open →(navigation)→ closed or
  re-scoped (edge case rule); ⌥⌘I toggles.
- `Route`: any → any via sidebar/KPI/router; stale-entity fallback to parent module.
