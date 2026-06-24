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

> **Note on entity naming:** `docs/technical-design.md §10` (pre-Round 7) still lists `PersonalTransaction`, `BusinessTransaction`, `PersonalCategory`, `PersonalBudget`, and `BusinessEntity` as discrete entries — these are pre-R6 legacy names. The canonical names are `Transaction`, `Category`, `Budget`, and the account-group object. `[FIX-M6]` and `[FIX-C6]` in `docs/project-management.md` track the update; fix the §10 entity list before Phase 3.

### Notes

- `Account` is the master registry entity (all account groups, including investment). Investment-specific fields (`tax_treatment`, `performance_tracking`) are optional properties on `Account`, not a separate `InvestmentAccount` type. The `PortfolioEngine` filters to `account_group: investment` rows when building portfolio projections.
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

- SwiftUI for macOS UI and scene management.
- Swift Charts for all chart rendering (pie/donut, sparklines, holdings heat map, monthly net-income, portfolio). Charts use real charting, not hand-authored placeholder SVGs; the prototype uses a real charting library as the equivalent.
- Observation for app state and model updates.
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

> **Business module note:** `Domain/Business/BusinessEngine.swift` appears in the layout above but has no entry in §3 service responsibilities and no roadmap build task. The current PRD and prototype model Business as an account-group type under Accounts (not a standalone module). `[FIX-C3]` and `[FIX-S2]` in `docs/project-management.md` track resolution. Until resolved: do not add `BusinessEngine` responsibilities here; treat business P&L logic as part of `AccountEngine`.

---

## 3. Service responsibilities

### CloudStorageProvider (protocol)
- Defines the minimum interface all storage backends must implement: `resolveWorkspaceURL() async throws -> URL`, observable `syncState`, `isAvailable: Bool`.
- `ICloudContainerService` is the v1 conforming implementation.
- Additional backends (Google Drive, Dropbox, local folder) conform to this protocol in V2.

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

### FileIndexService
- Recursively scan `.csv` and `.md`.
- Classify files.
- Compute hashes.
- Update manifest.
- Emit change events.

### FileWatcherService
- Observe file changes.
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

- **`SavingsGoalEngine`**: goal progress, target gap, funding schedule. No goal lifecycle states in v1 — every goal in `goals.csv` is active; the engine does not branch on status.

- **`PortfolioEngine`**: assets, the Portfolio container and its sleeves, allocation, performance; reads investment trades as `type = trade` rows from the unified ledger.

- **`BenchmarkEngine`**: S&P comparison windows across D/W/M/3M/6M/1Y/3Y/5Y periods, sector performance weighting.

- **`TaxEngine`**: realized gains, estimated payments, income summary, per-account effective rate.

- **`TaxPrepEngine`**: prep checklist, missing input detection, tax archive read/write, year-close flow.

- **`TaxAdjustmentEngine`** *(was `DeductionEngine`)*: tax-adjustment record management (deductions, credits, liabilities); standard-adjustment seeding from filing status and tax year; business-expense cross-reference with AccountEngine; tax-estimate projections; tax-document registry; taxable income minus adjustments projection.

- **`LinkingEngine`**: connect budget-to-goal, portfolio-to-tax, account-to-all-modules.

- **`OverviewEngine`**: aggregate KPI projections from all domain engines. When downstream engines (PortfolioEngine, TaxEngine) are stubs in Phase 3, OverviewEngine returns a typed "data not available" state — not nil, not empty placeholder values — so the Overview dashboard renders a distinct empty card rather than crashing or showing zeroes.
