# Core Domain — Data Model, Module Layout, Service Responsibilities

> Extracted from `docs/technical-design.md` in Round 7 (2026-06-24). The overview file
> (`technical-design.md`) links here for all domain-model and service-design detail.
> Locked decisions remain in `technical-design.md §21`.

---

## 1. Internal data model

### Canonical entities

- Workspace
- FileRecord
- ValidationIssue
- RepairAction
- Account
- AccountGroup *(first-class object; `group_type` = personal/employment/business/custom; provides the `account_group_id` referenced by Account and Transaction)*
- Liability
- AccountRule
- AccountEstimate
- Transaction *(unified; personal and business rows share the same type — distinguished by `account_group_id` and the `BX-` ID prefix)*
- Category
- Budget
- BudgetAllocation
- SavingsGoal
- SavingsProgress
- Asset
- Trade
- PricePoint
- BenchmarkPeriod
- Portfolio
- PortfolioSleeve
- SleeveTarget
- TaxAdjustment
- TaxEstimate
- TaxDocument
- EstimatedPayment
- TaxArchiveYear
- NoteDocument

> **Note on entity naming:** `docs/technical-design.md §10` (pre-Round 7) still lists `PersonalTransaction`, `BusinessTransaction`, `PersonalCategory`, `PersonalBudget`, and `BusinessEntity` as discrete entries — these are pre-R6 legacy names. The canonical names are `Transaction`, `Category`, `Budget`, and the account-group object. This PRD/TDD naming reconciliation is tracked as **UC-2** in [`docs/product-backlog.md`](../product-backlog.md) (the §10 list is authored-history; the canonical names above govern).

### Notes

- `Account` is the master registry entity (all account groups, including investment). It is a **single struct**; investment-specific fields (`tax_treatment`, `performance_tracking`, etc.) live in an optional nested `InvestmentMetadata?`, **not** a separate `InvestmentAccount` subtype (locked Round 8). The `PortfolioEngine` filters to `account_group: investment` rows when building portfolio projections.
- `BenchmarkPeriod` models the discrete comparison windows (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) used in the benchmark heat map.
- `Liability` is a first-class peer of `Asset`, held within an account. Debt fields live on `Liability`, not as columns on `Account`.
- `Portfolio` is the formal investment container above sleeves (Portfolio → Sleeve → Asset).

### Cross-domain entities

- AccountSummaryCard
- MonthlySnapshot
- GoalFundingLink
- SleeveFundingLink
- TaxPrepSummary
- TaxDeductionSummary
- BusinessMonthlySummary
- OverviewSummaryCard

---

## 2. Application architecture

### Recommended stack

- **macOS 15 (Sequoia)** minimum deployment target. Update to the latest stable macOS at Phase 1 build start if newer.
- **Xcode 16** (update to latest stable at Phase 1 build start) · **Swift 6**.
- SwiftUI for macOS UI and scene management.
- Swift Charts for all chart rendering (pie/donut, sparklines, holdings heat map, monthly net-income, portfolio). Charts use real charting, not hand-authored placeholder SVGs; the prototype uses a real charting library as the equivalent.
- Observation (`@Observable`) for app state and model updates. Requires macOS 14+; macOS 15 target satisfies this.
- Foundation `FileManager` for workspace access.
- `NSFileCoordinator` for coordinated reads and writes where needed around iCloud documents.
- Uniform Type Identifiers for file-type declaration and import/export boundaries.

### Module layout

```text
FinanceWorkspaceApp/
  App/
    FinanceWorkspaceApp.swift
    AppRouter.swift
    AppState.swift
  Platform/
    WorkspaceManager.swift
    CloudStorageProvider.swift       (protocol)
    ICloudContainerService.swift     (v1 CloudStorageProvider implementation)
    FileIndexService.swift
    FileWatcherService.swift
    BackupService.swift
    FileCoordinatorService.swift
  Parsing/
    CSV/
      CSVParserService.swift
      CSVSchemaRegistry.swift
      CSVNormalizer.swift
    Markdown/
      MarkdownParserService.swift
      FrontMatterParser.swift
  Domain/
    Accounts/
      AccountEngine.swift
      AccountModels.swift
    Budget/
      BudgetEngine.swift
      BudgetModels.swift
    Savings/
      SavingsGoalEngine.swift
    Investments/
      PortfolioEngine.swift
      BenchmarkEngine.swift
    Taxes/
      TaxEngine.swift
      TaxPrepEngine.swift
      TaxAdjustmentEngine.swift
    CrossDomain/
      LinkingEngine.swift
      OverviewEngine.swift
  Validation/
    ValidationEngine.swift
    RuleCatalog.swift
    RepairService.swift
  Persistence/
    ManifestStore.swift
    SettingsStore.swift
  UI/
    Overview/
    Accounts/
    Budget/
    SavingsInvestments/
    Taxes/
    Notes/          (V2)
    Issues/         (V2)
    Files/          (V2)
    Shared/
  Scripts/
    bootstrap-workspace.swift
    validate-workspace.swift
    repair-workspace.swift
    import-csv.swift
    export-summary.swift
```

> **Business module (resolved Round 7):** Business is a **group type** under Accounts — managed through the account-group system (`group_type = business`). There is no standalone `BusinessEngine.swift` or `Domain/Business/` subfolder. All business P&L logic (monthly net income, category budget variance, expense summaries, Schedule C cross-reference) lives in `AccountEngine`. `[FIX-C3]` and `[FIX-S2]` retired. The module layout above does not include a Business subfolder.

---

## 3. Service responsibilities

### CloudStorageProvider (protocol)
- Defines the minimum interface all storage backends must implement: `resolveWorkspaceURL() async throws -> URL`, observable `syncState`, `isAvailable: Bool`.
- `ICloudContainerService` is the v1 conforming implementation.
- Additional backends (Google Drive, Dropbox, local folder) conform to this protocol in V2.
- In **DEBUG builds the default provider is a local-folder provider** rooted at `~/Finance-Dev/` (populated by `fixture-generate`), so development needs no entitlement/signing round-trips and runs on CI. Live iCloud is exercised in Release/TestFlight builds. (Locked Round 8.)

> **Design constraint:** `AccountEngine` must expose only read-only projection interfaces. It must not absorb domain logic from Tax or Investment engines. All other engines depend on `AccountEngine`; keeping it as a pure read model prevents it from becoming a monolithic bottleneck.

### WorkspaceManager
- Resolve workspace URL via the active `CloudStorageProvider`.
- Create initial directory tree.
- Restore last active workspace.
- Validate minimum required paths.
- Expose workspace state to UI.

### ICloudContainerService
- Conforms to `CloudStorageProvider`.
- Resolve ubiquity container.
- Expose availability state.
- Provide diagnostics for missing entitlements or unavailable container.
- **Sync-first write gate** (locked Round 7): exposes per-file sync state (`available`, `downloading`, `uploading`, `conflict`, `error`). The write layer queries this before applying any write plan. If the target file is not `available` locally, the write is blocked with a user-visible "File syncing — edits will be available shortly" message. Write actions in the UI are disabled globally while the workspace `syncState` is `syncing` or any targeted file is in `downloading` state.
  - **On launch**: the app checks workspace sync state before enabling write actions. A "Syncing workspace…" indicator replaces action buttons until all monitored files are `available`.
  - **On write attempt**: `WritePlanBuilder` queries `ICloudContainerService.syncState(for: targetFile)` before building the plan. If not `available`, the write is deferred and the user is notified inline (non-blocking banner, not a modal).
  - **On iCloud push** (external file change detected by `FileWatcherService`): the affected file is marked `downloading` in the sync state; write actions targeting it are disabled until re-index completes and the file returns to `available`.
  - **`NSFileCoordinator`**: all reads and writes on monitored files go through `FileCoordinatorService` / `NSFileCoordinator` to serialize concurrent access at the OS level. This is the primary technical guard against overwriting a file that iCloud is concurrently updating.
  - **Sync-state source** (locked Round 8): the per-file sync state is derived from **`NSMetadataQuery`** (scope `NSMetadataQueryUbiquitousDocumentsScope`) attributes — `NSMetadataUbiquitousItemDownloadingStatusKey`, percent-downloaded, upload/download-in-progress, and conflict flags — not hand-tracked. Sync state is held in memory, never persisted to the manifest.
  - **Conflict resolution** (locked Round 8): v1 does not auto-merge. Unresolved conflicts are surfaced from `NSFileVersion.unresolvedConflictVersions` with a "Keep mine / Keep iCloud / Keep both" choice.

### FileCoordinatorService
- Wraps `NSFileCoordinator` for iCloud-safe coordinated reads and writes.
- Serializes concurrent access at the OS level so a write never clobbers a file iCloud is concurrently updating; used by every read/write on monitored files.

### ManifestStore
- Reads/writes the **device-local** manifest at `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json` (kept out of the synced container so it cannot conflict across machines).
- Maintains the last-indexed snapshot and the per-file index + validation cache.
- Rebuilds from a full scan if the manifest is missing or corrupt — never treats absence as data loss.

### SettingsStore
- Reads/writes `Taxes/settings.csv` (filing status, tax year, default currency, timezone).
- Exposes a typed `WorkspaceSettings` observable to the UI.

### FileIndexService
- Recursively scan `.csv` and `.md`.
- Classify files.
- Compute hashes.
- Update manifest.
- Emit change events.

### FileWatcherService
- Observe file changes. **Mechanism (locked Round 8):** `NSMetadataQuery` for the iCloud provider (it also yields the per-file sync state above) and **FSEvents** for the local-folder provider. `DispatchSource` (single-fd, doesn't scale to a tree, blind to iCloud placeholder transitions) and hand-rolled `NSFilePresenter`-as-watcher are rejected; `NSFilePresenter`/`NSFileCoordinator` are used only for read/write coordination.
- Debounce rescans.
- Notify dependent projections.

### CSVParserService
- Parse raw CSV.
- Map headers.
- Enforce schema.
- Normalize types.
- Attach source provenance.

### MarkdownParserService
- Parse front matter.
- Extract body.
- Validate note types and links.

### ValidationEngine
- Run per-file validation.
- Run cross-file reference validation.
- Run domain logic validation.
- Classify issues as error, warning, info.
- Classify issues as repairable or manual.

### RepairService
- Create missing files from templates.
- Normalize headers.
- Inject missing optional columns.
- Regenerate manifest.
- Create backup before every write.

### Domain engines

- **`AccountEngine`**: aggregate account overview (all accounts, monthly inflow, YTD net income, cash inflow vs retained equity); account-group grouping (personal, employment, business, custom); per-group detail screen (individual-account cards, business P&L with inline ledger, paycheck/stock details, personal net worth & cash flow trends); per-account detail screen (monthly gross vs expenses/tax, YTD net income, transactions table); derives account balances and `Liability.principal_balance` from the ledger; account rule and estimate projections; resolves multi-entry transaction groups; cross-references all unified transactions and investment records. **Read-only projection interfaces only — does not absorb domain logic from Tax or Investment engines.**

- **`BudgetEngine`**: budget totals, category variance, 3-month trailing averages, contribution planning; resolves each Budget's scope (account-groups/accounts) over its allocations.

- **`SavingsGoalEngine`**: goal progress, target gap, funding schedule. Minimal goal lifecycle in v1: `status ∈ {active, archived}` (`completed` is derived from progress ≥ target; `paused` is not in v1). The engine branches only on `archived` (excluded from active views).

- **`PortfolioEngine`**: assets, the Portfolio container and its sleeves, allocation, performance; reads investment trades as `type = trade` rows from the unified ledger.

- **`BenchmarkEngine`**: S&P comparison windows across D/W/M/3M/6M/1Y/3Y/5Y periods, sector performance weighting.

- **`TaxEngine`**: realized gains, estimated payments, income summary, per-account effective rate.

- **`TaxPrepEngine`**: prep checklist, missing input detection, tax archive read/write, year-close flow.

- **`TaxAdjustmentEngine`** *(was `DeductionEngine`)*: tax-adjustment record management (deductions, credits, liabilities); standard-adjustment seeding from filing status and tax year; business-expense cross-reference with AccountEngine; tax-estimate projections; tax-document registry; taxable income minus adjustments projection.

- **`LinkingEngine`**: connect budget-to-goal, portfolio-to-tax, account-to-all-modules.

- **`OverviewEngine`**: aggregate KPI projections from all domain engines. When downstream engines (PortfolioEngine, TaxEngine) are stubs in Phase 3, OverviewEngine returns a typed "data not available" state — not nil, not empty placeholder values — so the Overview dashboard renders a distinct empty card rather than crashing or showing zeroes.
