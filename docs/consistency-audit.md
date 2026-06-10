# Cross-Document Consistency Audit

**Date**: 2026-06-10  
**Documents reviewed**:
- `docs/PRD.md`
- `docs/technical design.md`
- `docs/roadmap-v1.md`

**Method**: Full read of all three documents, cross-referenced for conflicts, gaps, and naming drift. Findings are organized by severity. Each finding cites the specific location in each document.

---

## Severity key

| Severity | Meaning |
|---|---|
| **Critical** | Direct conflict that will break the build, cause data model errors, or produce contradictory implementation instructions |
| **Significant** | Functional gap, missing spec, or specification ambiguity that will cause confusion or rework during implementation |
| **Minor** | Naming drift, labeling inconsistency, or wording mismatch with no functional impact if not resolved before build |

---

## Critical findings

### C1 — `InvestmentAccount` still listed as a canonical entity after the unified model decision

**Conflict**: The unified accounts decision (locked 2026-06-10) removed `InvestmentAccount` as a separate type. Investment-specific fields are optional properties on `Account`. Despite this:

- **Tech Design §10** canonical entities list still includes `InvestmentAccount` as a discrete entry alongside `Account`
- **Roadmap Phase 1** dev task "Define canonical entity models" lists `InvestmentAccount` explicitly: `"Account, AccountRule, AccountEstimate, UnifiedTransaction, Category, BudgetPlan, SavingsGoal, SavingsProgress, InvestmentAccount, Holding..."`

The §10 note below the list correctly describes the unified model, but the list itself contradicts it. A developer following the list would create a separate `InvestmentAccount` type.

**Fix needed**: Remove `InvestmentAccount` from the §10 entity list; update the roadmap Phase 1 entity list to read `Account` with a note that investment-specific fields are optional properties.

---

### C2 — Phase 3 critical dependency references two paths that no longer exist

**Conflict**: The roadmap Phase 3 critical dependency block reads:

> "`Investments/accounts.csv`, `Business/entities.csv`, and all transaction files reference `account_id` from the master registry"

Both paths are wrong:
- `Investments/accounts.csv` was removed by the unified accounts decision. The master registry is `Accounts/accounts.csv`.
- `Business/entities.csv` has never existed. The entities/themes file is `Accounts/entities.csv`.

A developer using this as a dependency checklist would look for files that don't exist.

**Fix needed**: Update the Phase 3 dependency note to reference `Accounts/accounts.csv` and `Accounts/entities.csv`.

---

### C3 — `UI/Business/` in module layout with no corresponding navigation section or build task

**Conflict**:
- **Tech Design §11** module layout includes `UI/Business/` as a module folder
- **Tech Design §4** navigation structure has no top-level `Business` section — Business is a theme/entity type under Accounts, not a standalone module
- **Roadmap** has no `BusinessEngine` or Business UI build tasks in any phase
- **Tech Design §12** service responsibilities: all business logic (P&L, entity grouping, per-theme dashboards) is assigned to `AccountEngine`, not a `BusinessEngine`

The `UI/Business/` folder and the implied `BusinessEngine.swift` in `Domain/Business/` describe a module that has no navigation entry, no requirements section in §16, and no build phase in the roadmap. If a developer creates these files, they produce dead code.

**Fix needed**: Either remove `UI/Business/` and `Domain/Business/BusinessEngine.swift` from the module layout and assign Business responsibilities explicitly to `AccountEngine` in §12, or formally define Business as a navigation section with its own §16 requirements and roadmap tasks.

---

### C4 — Roadmap Phase 5 `SavingsInvestmentsView` sub-navigation includes "Categories" (removed in Round 3)

**Conflict**:
- **Roadmap Phase 5** development task: `SavingsInvestmentsView — "top-level view with Overview, Goals, Assets, and Categories sub-navigation"`
- **Tech Design §4** sidebar (updated Round 3): Savings & Investments has `Overview`, `Goals`, `Assets`, `Portfolio` — "Categories" was explicitly removed with the note "deferred — category and tag systems for Budget and S&I to be considered together"

A developer following the roadmap task would build a Categories sub-view that the navigation spec says should not exist.

**Fix needed**: Update the roadmap Phase 5 `SavingsInvestmentsView` task to match the §4 sidebar: `Overview`, `Goals`, `Assets`, `Portfolio`.

---

### C5 — Manifest example references a `Personal/transactions/` path that does not exist

**Conflict**:
- **Tech Design §9** manifest JSON example shows `"path": "Personal/transactions/2026-05.csv"` with `"domain": "personal"`
- **Tech Design §6** workspace folder structure has no `Personal/` folder. Transactions live at `Accounts/transactions/YYYY-MM.csv`.

This is the only specification document for the manifest shape. A developer writing `ManifestStore` would classify transaction files under the wrong path.

**Fix needed**: Update the §9 manifest example to use `"path": "Accounts/transactions/2026-05.csv"` and `"domain": "accounts"` (or confirm the correct domain label for account transactions).

---

### C6 — `BusinessEntity` used as an entity name in Tech Design §10, but the file/type covers all four entity types (personal, employment, business, custom)

**Conflict**:
- **Tech Design §10** canonical entities list uses the name `BusinessEntity`
- **Tech Design §8.14** spec title is "Customizable entities/themes CSV" and `entity_type` enum is `personal`, `employment`, `business`, `custom`
- **PRD §5** and **Tech Design §4** both call these "themes and entities" or "themes/entities"

Naming this entity `BusinessEntity` implies it only represents business accounts, which is incorrect — it covers personal assets, employment, and custom types too. Using this name in code would be misleading and likely cause confusion when a personal-type entity is handled by `BusinessEntity`.

**Fix needed**: Rename `BusinessEntity` to `Entity` or `WorkspaceEntity` throughout Tech Design §10 and anywhere it appears in service descriptions.

---

## Significant findings

### S1 — PRD requires a Markdown native viewer "in v1" but Notes is deferred to V2

**Conflict**:
- **PRD §4 Markdown ingestion** functional requirements include: `"Provide a readable native viewer in v1."`
- **PRD Out of Scope**: `"Notes viewer and editor (V2)."`
- **Roadmap Out of Scope**: `"Notes viewer and editor | V2"`

These directly contradict each other within the PRD itself. §4 says build a viewer; the scope section says defer it. The intent is likely that Notes as a standalone module is V2, but Markdown viewing of note content (e.g. in the right detail pane) may still be needed in v1 for tax notes and strategy notes linked from other modules.

**Fix needed**: Clarify whether inline Markdown rendering (in the right pane) is in scope for v1 independent of the Notes standalone module. If yes, update §4 to be specific about where Markdown is rendered. If no, remove the "native viewer in v1" clause from §4.

---

### S2 — `BusinessEngine` in module layout with no service description and no roadmap build task

**Conflict**:
- **Tech Design §11** module layout: `Domain/Business/BusinessEngine.swift` is listed
- **Tech Design §12** service responsibilities: `BusinessEngine` has no entry. All business logic is described under `AccountEngine`
- **Roadmap**: No phase includes a `BusinessEngine` build task

The file exists in the architecture spec but has no defined responsibilities and no build phase. Either it's a vestige that should be removed, or it represents intended functionality that needs to be broken out from `AccountEngine` and given its own spec and roadmap entry.

**Fix needed**: If business logic stays inside `AccountEngine`, remove `Domain/Business/BusinessEngine.swift` from the §11 module layout. If it should be a separate service, add it to §12 with defined responsibilities and add a build task to the appropriate roadmap phase.

---

### S3 — Tech Design §4 Savings & Investments sidebar has an "Overview" sub-item with no corresponding requirements in §16

**Conflict**:
- **Tech Design §4** sidebar structure: Savings & Investments has `Overview`, `Goals`, `Assets`, `Portfolio`
- **Tech Design §16** S&I requirements: structured under "Goals must show:", "Assets must show:", "Portfolio must show:" — there is no "Overview" section
- **Roadmap Phase 5** development tasks: `SavingsInvestmentsView` is the top-level view but no `SavingsInvestmentsOverviewView` component is specified

The user can navigate to "Overview" under Savings & Investments but there are no requirements for what it shows.

**Fix needed**: Either add "Overview must show:" requirements to §16 for the S&I Overview, or rename the sidebar item so it isn't a separate navigation destination (e.g. make it the default landing within the section rather than an explicit sub-item).

---

### S4 — `savings-goal-contributions.csv` in workspace structure with no §8 spec

**Conflict**:
- **Tech Design §6** workspace folder structure lists `Budget/savings-goal-contributions.csv`
- No §8.x spec exists for this file — no columns, no purpose, no schema
- The file is not referenced anywhere in §12 service responsibilities or §16 UI requirements

It is unclear whether this file tracks budget-to-goal contribution links (as `GoalFundingLink` in §10 suggests) or whether it has been superseded by the `savings_goal_id` column on `Accounts/transactions/YYYY-MM.csv`.

**Fix needed**: Either add a §8 spec for `Budget/savings-goal-contributions.csv` defining its purpose and columns, or remove it from the §6 folder structure and confirm that `savings_goal_id` on transaction rows is the sole mechanism for budget-to-goal linking.

---

### S5 — `OwnerDistribution` in PRD and roadmap but not in Tech Design §10 entity list and no CSV spec

**Conflict**:
- **PRD data model** Accounts domain: lists `OwnerDistribution` as a canonical entity
- **Roadmap Phase 1** dev task: lists `OwnerDistribution` in the entity models to define
- **Tech Design §10** canonical entities list: does not include `OwnerDistribution`
- No §8.x spec exists for an owner distributions file

If this entity is needed (e.g. for tracking business owner draws or equity distributions), it requires a file spec and a domain entity definition. If it's not needed in v1, it should be removed from the PRD data model and roadmap task list.

**Fix needed**: Either add `OwnerDistribution` to Tech Design §10 and create a §8 CSV spec, or remove it from the PRD data model table and roadmap Phase 1 entity list.

---

### S6 — `FileCoordinatorService`, `ManifestStore`, and `SettingsStore` are in the module layout but have no service descriptions in §12

**Conflict**:
- **Tech Design §11** module layout: `Platform/FileCoordinatorService.swift`, `Persistence/ManifestStore.swift`, `Persistence/SettingsStore.swift`
- **Tech Design §12** service responsibilities: none of these three services have entries

`FileCoordinatorService` wraps `NSFileCoordinator` for iCloud-safe reads and writes — this is non-trivial and needs a service spec. `ManifestStore` and `SettingsStore` are referenced by name in the roadmap build tasks but have no §12 entry defining their responsibilities.

**Fix needed**: Add §12 service descriptions for `FileCoordinatorService`, `ManifestStore`, and `SettingsStore`.

---

### S7 — Goal `status` enum in §8.5 is undefined, but roadmap assumes an "archived" state

**Conflict**:
- **Tech Design §8.5** savings goals CSV: `status` column is typed as `enum` but the valid values are not listed
- **Roadmap Phase 4** design task: "Goals overview: goal card anatomy... active vs archived tabs"
- **Roadmap Phase 5** dev task: `GoalsListView — "goal cards with progress bar, tap → goal detail"` (archived tabs not mentioned here, creating an internal roadmap inconsistency too)

Without a defined `status` enum, the `SavingsGoalEngine` and `GoalsListView` cannot be built consistently. The "archived" state needs to be a defined enum value.

**Fix needed**: Add the `status` enum values to §8.5 (candidates: `active`, `paused`, `completed`, `archived`). Reconcile Phase 4 and Phase 5 roadmap tasks so both mention or both omit the archived tab.

---

### S8 — Two-mode workspace described in Tech Design §5 but "advanced mode" is never scoped

**Conflict**:
- **Tech Design §5** workspace strategy: describes two modes — (1) app-owned iCloud ubiquity container, and (2) "Advanced mode: user-selected iCloud Drive folder"
- **PRD §1** workspace management: mentions only the app-owned container and a "future extension for advanced user-selected folders"
- The locked decision confirms only the app-owned container for v1
- The "advanced mode" has no locked status, no roadmap task, and no defined scope boundary

Listing "advanced mode" as a named option in the architecture spec — without explicitly marking it as V2 deferred — creates ambiguity about whether it must be designed for in Phase 1.

**Fix needed**: Add a clear V2 deferral marker to the "advanced mode" description in §5, matching the PRD's "future extension" language.

---

### S9 — PRD account group "Everyday Banking" does not match Tech Design `account_group` enum value `checking`

**Conflict**:
- **PRD §5** account types table: group name is "Everyday Banking" (personal/joint checking, cash management accounts)
- **Tech Design §8.21** `account_group` enum: value is `checking`

These refer to the same group. A developer reading the PRD would create a display group called "Everyday Banking" but the CSV enum value and domain model use `checking`. Without explicit mapping, this creates inconsistency between the UI display label and the data layer value. The same discrepancy exists for "Loans & Debt" (PRD) vs `loan` (Tech Design).

**Fix needed**: Add a display-name-to-enum-value mapping table to either §5 of the PRD or §8.21 of the Tech Design. Specifically: "Everyday Banking" → `checking`, "Loans & Debt" → `loan`, "Credit Cards" → `credit_card`.

---

## Minor findings

### M1 — Layer count differs across documents

- **PRD §"Internal architecture model"**: 4 layers (File, Parsing, Domain, Projection)
- **Tech Design §3**: 6 layers (Storage, Indexing, Parsing, Domain, Projection, Presentation)
- **CLAUDE.md**: 5 layers (File, Parsing, Domain, Projection, Presentation)

These are different levels of decomposition of the same architecture, not a true conflict, but a reader moving between documents will encounter three different layer counts for the same system.

**Fix needed**: Align the PRD and CLAUDE.md to use the 6-layer model from the Tech Design, or add a note in Tech Design §3 explaining the PRD's 4-layer model is a simplified view.

---

### M2 — `ReportingEngine` in PRD core modules but not in Tech Design

- **PRD Technical Architecture** core modules lists `ReportingEngine` in the Domain Layer
- **Tech Design §11** and **§12**: no `ReportingEngine` exists; reporting/export is handled by `ExportService` in Phase 6 and by domain engine projections

Likely superseded, but the PRD still names it.

**Fix needed**: Remove `ReportingEngine` from the PRD core modules list or replace it with `ExportService`.

---

### M3 — PRD data model includes entities not present in Tech Design §10

The PRD data model table includes entities that either have no Tech Design counterpart or use different names:

| PRD entity | Tech Design status |
|---|---|
| `GoalContribution` | Not in §10; appears to be the `savings_goal_id` field on transactions |
| `GoalStatusSnapshot` | Not in §10; may map to `SavingsProgress` |
| `Security` | Not in §10; likely maps to `Holding` or is just a ticker reference |
| `Lot` | Not in §10; `Trade` + tax-lots.csv covers this |
| `Position` | Not in §10; derived projection, not a stored entity |
| `IncomeEvent` | Not in §10 |
| `RealizedGain` | Not in §10; derived from `Trade` records |
| `TaxPrepIssue` | Not in §10; likely a `ValidationIssue` tagged as tax-relevant |
| `BudgetContribution` | Not in §10 |
| `Merchant` | Not in §10; a field on transactions, not a first-class entity |
| `ImportIssue` | Not in §10; likely a `ValidationIssue` |
| `SchemaVersion` | Not in §10; a metadata field, not an entity |
| `BenchmarkSeries` | Not in §10; §10 has `BenchmarkPeriod` instead |
| `MonthlyReview`, `StrategyNote` | Not in §10; subtypes of `NoteDocument` |

**Fix needed**: Reconcile the PRD data model table with Tech Design §10. Either update the PRD table to match §10 naming, or add a mapping note explaining which PRD entities correspond to which Tech Design types.

---

### M4 — PRD says "MVVM for presentation logic"; Tech Design doesn't mention MVVM

- **PRD Technical Architecture**: `"MVVM for presentation logic"`
- **Tech Design §11**: `"Observation for app state and model updates"` — no mention of MVVM

These aren't strictly contradictory (Observation-based SwiftUI can follow MVVM patterns), but the PRD's explicit MVVM recommendation creates an expectation the Tech Design doesn't address.

**Fix needed**: Either add a note in Tech Design §11 confirming MVVM as the pattern for view models, or update the PRD to say "Observation-based state management" to match the Tech Design.

---

### M5 — PRD non-goals say AI integration is a non-goal; roadmap says V2

- **PRD Non-goals**: `"AI model integrations to analyze performance"` — listed as a non-goal with no timeline
- **Roadmap Out of Scope**: `"AI-driven analysis or recommendations | V2"` — explicitly deferred to V2

"Non-goal" implies it will not be built; "V2" implies it will. These send different signals about long-term product intent.

**Fix needed**: Align the PRD non-goals entry to say "V2 deferred" rather than an unqualified non-goal.

---

### M6 — Roadmap Phase 1 entity list uses `PersonalTransaction` and `BusinessTransaction` names inconsistent with unified model

- **Roadmap Phase 1** dev task "Define canonical entity models" uses `PersonalTransaction` as an entity name
- **Tech Design §10** uses `PersonalTransaction` too, but the file spec (§8.2) describes a unified transaction model in `Accounts/transactions/` covering all domains
- A `BusinessTransaction` is listed separately in §10 even though business transactions use the same unified file, distinguished by `entity_id`

**Fix needed**: Replace `PersonalTransaction` and `BusinessTransaction` with a single `Transaction` or `UnifiedTransaction` entity in §10 and the roadmap task list, with a note that domain filtering (personal vs business) is done by `entity_id` and `account_group` at query time.

---

### M7 — Tech Design §4 and §16 inconsistency on whether S&I has an "Overview" sub-nav item

- **Tech Design §4**: S&I sidebar shows `Overview`, `Goals`, `Assets`, `Portfolio`
- **Tech Design §16**: S&I requirements are structured under `Goals must show:`, `Assets must show:`, `Portfolio must show:` — the first item is "Goals", not "Overview"

If the user navigates to the "Overview" sub-item, there are no requirements describing what they see.

**Fix needed**: See S3 above — either define S&I Overview requirements in §16 or remove "Overview" from the sidebar sub-items and land users on Goals by default.

---

### M8 — Goal archived/active tab inconsistency within the roadmap itself

- **Roadmap Phase 4** design task: "Goals overview: goal card anatomy... active vs archived tabs"
- **Roadmap Phase 5** dev task: `GoalsListView — "goal cards with progress bar, tap → goal detail"` — no mention of tabs

One phase specifies the tabs; the next phase's dev task omits them, creating an internal contradiction.

**Fix needed**: Add the active/archived tab to the Phase 5 `GoalsListView` task description.

---

## Summary table

| ID | Severity | Topic | Fix location |
|---|---|---|---|
| C1 | Critical | `InvestmentAccount` still in entity list and roadmap after unified model decision | Tech Design §10, Roadmap Phase 1 |
| C2 | Critical | Phase 3 dependency cites `Investments/accounts.csv` and `Business/entities.csv` (both removed/wrong) | Roadmap Phase 3 |
| C3 | Critical | `UI/Business/` and `BusinessEngine` in module layout with no nav section, §12 description, or roadmap task | Tech Design §11, §12, Roadmap |
| C4 | Critical | `SavingsInvestmentsView` task lists "Categories" sub-nav (removed in Round 3) | Roadmap Phase 5 |
| C5 | Critical | Manifest JSON example uses `Personal/transactions/` path (folder doesn't exist) | Tech Design §9 |
| C6 | Critical | `BusinessEntity` name implies business-only but covers personal/employment/business/custom | Tech Design §10 |
| S1 | Significant | PRD §4 requires Markdown viewer "in v1" but Notes is deferred to V2 in PRD out-of-scope | PRD §4, PRD Scope |
| S2 | Significant | `BusinessEngine` in module layout with no service description and no roadmap build task | Tech Design §11, §12, Roadmap |
| S3 | Significant | S&I "Overview" sub-nav exists in §4 sidebar with no requirements in §16 | Tech Design §4, §16 |
| S4 | Significant | `savings-goal-contributions.csv` in folder structure with no §8 spec | Tech Design §6, §8 |
| S5 | Significant | `OwnerDistribution` in PRD and roadmap with no Tech Design entity or CSV spec | PRD, Tech Design §10, §8, Roadmap Phase 1 |
| S6 | Significant | `FileCoordinatorService`, `ManifestStore`, `SettingsStore` missing from §12 service descriptions | Tech Design §12 |
| S7 | Significant | Savings goal `status` enum undefined; archived state assumed but not specified | Tech Design §8.5, Roadmap Phase 4, Phase 5 |
| S8 | Significant | "Advanced mode" workspace in Tech Design §5 never formally scoped or deferred | Tech Design §5 |
| S9 | Significant | PRD group name "Everyday Banking" vs Tech Design enum `checking` (also "Loans & Debt" vs `loan`) | PRD §5, Tech Design §8.21 |
| M1 | Minor | Layer count is 4 (PRD), 5 (CLAUDE.md), or 6 (Tech Design) | PRD, CLAUDE.md |
| M2 | Minor | `ReportingEngine` in PRD core modules; not in Tech Design | PRD Technical Architecture |
| M3 | Minor | PRD data model has ~13 entities not present in Tech Design §10 | PRD Data Model, Tech Design §10 |
| M4 | Minor | PRD says MVVM; Tech Design says Observation-based (no mention of MVVM) | PRD, Tech Design §11 |
| M5 | Minor | PRD calls AI integration a non-goal; roadmap says V2 | PRD Non-goals, Roadmap |
| M6 | Minor | `PersonalTransaction` / `BusinessTransaction` in §10 and roadmap inconsistent with unified transaction model | Tech Design §10, Roadmap Phase 1 |
| M7 | Minor | S&I "Overview" appears in §4 sidebar but not in §16 requirements (duplicate of S3 at minor scope) | Tech Design §4, §16 |
| M8 | Minor | Goals active/archived tabs in Phase 4 design task but omitted from Phase 5 dev task | Roadmap Phase 4, Phase 5 |

---

## Recommended fix priority

**Fix before Phase 1 build starts (C1–C6, S1–S2):**
C1, C2, C4, C5 can be fixed with targeted edits in 15–30 minutes total. C3 (BusinessEngine) and C6 (entity naming) require a short architectural decision. S1 (Markdown viewer) requires a product call on scope.

**Fix before Phase 2 build starts (S3–S9):**
S4 (savings-goal-contributions.csv) and S5 (OwnerDistribution) each require either a new spec or an explicit removal decision. S7 (goal status enum) blocks implementation of `SavingsGoalEngine`.

**Fix opportunistically (M1–M8):**
Minor findings can be addressed as each phase's documents are updated during normal doc workflow. None block implementation.

---

*Last updated: 2026-06-10*
