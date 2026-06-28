# Phase 1 Data Model — Foundation & Architecture

Phase 1 **defines the typed models** (the stable contract downstream phases compile against). It does
**not** implement domain engines or projections. Field-level CSV column specs are the authority in
`docs/architecture/containers-and-budgets.md §3`; this file captures the model shapes, relationships,
and the invariants Phase 1 must encode. All amounts are `Decimal`; all dates ISO-8601; IDs are stable
strings.

## Platform entities (`Platform/`, `Validation/`)

### Workspace
- Fields: `id` (workspace_id), `rootURL`, `provider` (icloud | localFolder), `requiredPaths: [String]`, `availability: WorkspaceAvailability`.
- Relationships: owns the file tree; has many `FileRecord`.
- Invariants: `requiredPaths` must all exist for the workspace to validate as complete.

### FileRecord
- Fields: `path` (workspace-relative), `domain` (accounts | budget | savings | investments | taxes | notes | meta), `subtype`, `schemaVersion: Int`, `hash` (sha256), `modifiedAt`, `byteSize`, `rowCount`, `lastIndexedAt`, `validationStatus` (ok | warning | error | unvalidated).
- Relationships: belongs to `Workspace`; aggregated into `Manifest`.
- Invariants: `(path)` unique; `hash` recomputed on change; never authoritative over the file bytes. Only files in the finance content tree + root `Workspace.md` are recorded (the `.finance-meta/` subtree is excluded). A file that cannot be read/hashed is still recorded, with `validationStatus = error`, so the failure is visible and the scan continues (FR-011a).

### Manifest
- Fields: `manifestSchemaVersion`, `appVersion`, `workspaceId`, `lastIndexedAt`, `files: [FileRecord]`.
- Location: device-local, `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`.
- Invariants: a **regenerable cache** — a missing/corrupt manifest triggers a full rescan; never stored in the synced container; excludes per-file sync state and repair history.

### FileChangeEvent
- Emitted by `FileIndexService` on each detected delta. Fields: `kind` (added | changed | deleted), `path`, `fileRecord?` (nil for `deleted`). Transient (not persisted); consumed by dependent projections in later phases.

### SyncStatus
- Enum (per-file and workspace-level): `available | notSignedIn | containerUnavailable | syncing | localCopyStale | fileMissingLocally | conflictDetected`.
- Source: derived from `NSMetadataQuery`; held in memory, never persisted to the manifest.
- Transitions: driven by OS events; `conflictDetected` is resolved only by explicit user choice.

### ValidationIssue (stub contract — full behavior Phase 2)
- Fields: `ruleId` (`VAL-<TIER>-<NNN>`), `tier` (file | crossFile | domain), `severity` (error | warning | info), `repairClass` (auto | manual | none), `message`, `filePath`, `rowRef?`.

### RepairAction (stub contract — full behavior Phase 2)
- Fields: `issueRef`, `kind` (createFile | normalizeHeader | injectOptionalColumn | createFolder), `preview`, `backupPath`, `appliedAt?`.

## Canonical domain entities (`Domain/**/*Models.swift`)

> Models only in Phase 1. Engines (AccountEngine, etc.) are Phase 3+.

### Account *(master registry — single struct)*
- Fields: `accountId`, `displayName`, `institution`, `accountGroup` (enum: employment, business, credit_card, investment, savings, checking, loan), `accountType`, `status` (draft | active | frozen | closed), `currentBalance` (cached/derived), `accountGroupId` (FK → AccountGroup), optional nested `InvestmentMetadata?` (`taxTreatment`, `performanceTracking`).
- Invariants: `accountId` is referenced by every transaction file; `isActive` derived from `status == active`. **No `InvestmentAccount` subtype.**

### InvestmentMetadata (nested, optional on Account)
- Fields: `taxTreatment`, `performanceTracking`, … (applies only to `accountGroup == investment`).

### AccountGroup
- Fields: `accountGroupId`, `name`, `groupType` (personal | employment | business | custom).

### Liability *(first-class peer of Asset)*
- Fields: `liabilityId`, `accountId` (held within an account), `principalBalance` (derived), debt fields (rate, term, …).

### AccountRule / AccountEstimate
- Rule: account-scoped behavior (e.g. yield); Estimate: projected figures. Model stubs in Phase 1.

### Transaction *(unified ledger row)*
- Fields: `transactionId`, `accountId` (FK → Account), `date`, `amount` (Decimal; negative = debit, positive = credit), `categoryId?`, `savingsGoalId?`, `type` (e.g. `trade`), `groupId?`, `groupRole?` (gross | net | withholding | credit | debit), `sendingAssetId?`, `receivingAssetId?`, `liabilityId?`, `source_file`/`source_row` provenance.
- Invariants: personal vs business by `accountGroupId` + `BX-` ID prefix; multi-entry rows share `groupId` (a connector, not a PK) and move atomically; transfers net to zero; gross/net groups reconcile `net = gross − Σ(withholding)`.

### Category / Budget / BudgetAllocation
- Category: `categoryId`, `name`, `parentCategoryId?`, `categoryGroupId?`, `defaultBudgetBehavior`, `taxRelevant`. Budget: scope over account-groups/accounts. BudgetAllocation: per-category plan rows.

### SavingsGoal / SavingsProgress
- SavingsGoal: `goalId`, `name`, `targetAmount`, `targetDate`, `monthlyTarget`, `sourceAccountId`, **`status` (active | archived)**, `linkedNoteId?`. (`completed` is derived from progress ≥ target; `paused` not in v1.)
- SavingsProgress: snapshot of goal balance over time.

### Asset / Trade / PricePoint / BenchmarkPeriod
- Asset: `assetId`, `currentValue`, `securityClass`, … Trade: folded into the unified ledger as `type = trade`. PricePoint: ticker price series. BenchmarkPeriod: D/W/M/3M/6M/1Y/3Y/5Y windows.

### Portfolio / PortfolioSleeve / SleeveTarget
- Portfolio: investment container (`portfolioId`). Sleeve re-parents under `portfolioId`. SleeveTarget: target weights.

### TaxAdjustment / TaxEstimate / TaxDocument / EstimatedPayment / TaxArchiveYear
- TaxAdjustment: `adjustmentType` union enum (standard, above_the_line, itemized, business-expense, credit, liability); links to a transaction/category/asset/liability/account/account-group. Others are model stubs for later phases.

### NoteDocument
- Fields: `type` (workspace, monthly-review, strategy, tax-note, …), front-matter metadata, `period?`, linked entity IDs. v1 parses front matter only (body rendering is V2).

### Cross-domain projection models (`Domain/CrossDomain/`)
- `AccountSummaryCard`, `OverviewSummaryCard`, `MonthlySnapshot`, `GoalFundingLink`, `SleeveFundingLink`, `TaxPrepSummary`, `TaxDeductionSummary`, `BusinessMonthlySummary` — type definitions only in Phase 1 (populated by engines in Phase 3+).

## Relationships (summary)

- `Account.accountId` ← referenced by `Transaction`, `Liability`, `AccountRule`, `AccountEstimate`.
- `AccountGroup.accountGroupId` ← referenced by `Account`, `Transaction`.
- `Portfolio` → `PortfolioSleeve` → `Asset` (containment); `SleeveTarget` per sleeve.
- `SavingsGoal.goalId` ← referenced by `Transaction.savingsGoalId` (sole budget-to-goal link).
- `Workspace` → many `FileRecord` → aggregated in `Manifest`.

## State transitions

- **Account.status**: draft → active → frozen → closed (one-directional in practice; `isActive` derived).
- **SavingsGoal.status**: active ↔ archived.
- **SyncStatus**: OS-driven; `conflictDetected` exits only via explicit user resolution.
- **FileRecord**: discovered → hashed/indexed → (on change) re-hashed/re-indexed → (on delete) removed.
