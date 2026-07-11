# Open Finance — Product Roadmap

**Project**: Personal Finance Workspace for macOS
**Project phase**: 🌱 **GROWTH** (entered 2026-07-09) — the MVP (v1) is code-complete; all forward
work flows **backlog → Growth roadmap → spec-driven delivery**
**Architecture reference**: File layer → Parsing layer → Domain layer → Projection layer → Presentation layer
**Last updated**: 2026-07-09 (Growth phase entered: Phase 7 closed via spec `008` (PRs #22/#23, CI
green); roadmap restructured — Growth pipeline on top, Phases 1–8 preserved below as the **MVP
delivery record**)

---

## Growth — active phase

The MVP shipped the complete v1 product (see the delivery record below). From here the roadmap is a
**pipeline**, not a phase plan:

1. **Source of work**: [`docs/product-backlog.md`](product-backlog.md) — the single prioritized
   backlog (*add user value* → *security & performance* ∥ *visual design*; effort-ordered;
   *under-consideration* items need a PRD/TDD reconciliation first).
2. **Promote**: the PM moves an item (or a coherent bundle) from the backlog into the **Readying**
   table below. If the item isn't yet inline with `docs/product-requirements.md` /
   `docs/technical-design.md`, the promotion includes the amendment (refinement-round or direct,
   per the doc workflow in `CLAUDE.md`).
3. **Ready & deliver**: each promoted item goes through Spec Kit on its own `NNN-` branch —
   `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
   `/speckit-implement` — with the design-adherence gate on any UI work.
4. **Close the loop**: on merge, the item moves to **Delivered** below and its backlog row closes.
   Anything consciously skipped during implementation is added **straight to
   [`docs/product-backlog.md`](product-backlog.md)** (Source column = source spec + task) — there
   is no residue phase and no separate follow-ups doc.

### Readying (promoted from the backlog — next up for spec-driven delivery)

| Backlog ID | Item | Branch / spec | Status |
|---|---|---|---|
| **UV-1** | Manual re-ordering of accounts & account groups in the sidebar (optional `sort_order` columns, safe-write path, all surfaces mirror; PRD §5 + architecture §3.14/§3.21 amended 2026-07-10; constitution v1.1.2 direct-manipulation carve-out) | `010-reorder-and-delete` / [spec](../specs/010-reorder-and-delete/spec.md) | **Implementation complete** 2026-07-10 (25/26 tasks; manual Flow 11 drag pass + PR pending) |
| **UV-2** | Delete inside the edit modal for accounts, account groups, and categories (locked R5/R7 delete-reassign convention; reuses the existing `requestDelete` → `ReferenceScanner` → picker → preview pipeline unchanged) | `010-reorder-and-delete` / [spec](../specs/011-delete-in-edit-modal/spec.md) | **Spec complete** 2026-07-11 — next: `/speckit-plan` |

> On merge: move these rows to *Delivered* below and close the backlog rows (UV-1, UV-2).

### Delivered in Growth

| Backlog ID | Item | Spec / PR | Merged |
|---|---|---|---|
| — | *None yet. PR [#23](https://github.com/billdingwall/open-finance/pull/23) (onboarding + CloudDocs distribution, Phase-8 triage, spec-008 completion) is the MVP-closing PR, in review.* | — | — |

---

# MVP — v1 delivery record (Phases 1–8, complete)

> **Everything from here down is the historical record of how the MVP was built** — the eight
> phases, what each delivered, what each consciously skipped (and where that went), and the locked
> decisions. Nothing below is open work: on 2026-07-09 every unchecked task was swept against the
> delivery and the backlog (one genuine gap surfaced → backlog **SP-10**), and the task lists were
> then condensed to these prose records. **Task-level detail lives in git history and in
> `specs/NNN-*/tasks.md`**; per-item residue provenance is the Source column of the backlog rows.


## Out of Scope for v1

The following were explicitly excluded from the MVP. **Each now has an Under-consideration entry
in [`docs/product-backlog.md`](product-backlog.md)** (added 2026-07-09) — promoting one follows
the Growth process, starting with the PRD amendment.

| Item | Deferred to | Backlog |
|---|---|---|
| Notes viewer and editor | V2 | UC-4 |
| Issues management standalone view | V2 | UC-5 |
| Files explorer | V2 | UC-6 |
| Budget rules and recurring automation | Post-MVP | UC-7 |
| Bank account sync | V2 | UC-8 |
| Brokerage API integration | V2 | UC-9 |
| Real-time market data | V2 | UC-10 |
| Live price ingestion strategy (endpoint choice, polling interval, error handling) | V2 | UC-11 (incl. benchmark sector data) |
| OCR ingestion of PDFs | V2 | UC-12 |
| Tax return filing engine | V2 | UC-13 |
| Multi-workspace / multi-user support | V2 | UC-14 |
| AI-driven analysis or recommendations | V2 | UC-15 |
| Alternative cloud storage providers (Google Drive, Dropbox, local folder) | V2 | UC-16 (CloudDocs variant shipped) |
| xlsx and other spreadsheet format ingestion and export | V2 | UC-17 |
| Savings goal lifecycle states (active/archived) — flat goal list in v1 | V2 | UC-18 |
| Dedicated sleeves screen — sleeve table lives on the Portfolio overview in v1 | V2 | UC-19 |
| Dedicated benchmark screen — heat map is a holdings table view toggle in v1 | V2 | UC-19 |
| Dedicated deductions screen — deductions content lives within Current Tax Year in v1 | V2 | UC-19 |
| Contextual filter bar / filter chips on module screens | V2 | UC-20 |

Inline period/account selection that a screen intrinsically needs stays in v1; only the dedicated filter-bar surface is deferred.

Estimated payments and gains & income are **not** out of scope — their functionality stays in v1,
surfaced within the Current Tax Year view rather than on dedicated screens.

---

## Phase Dependencies Overview

```
Phase 1: Foundation & Architecture
    ↓ (workspace + iCloud layer required)
Phase 2: Parsing, Validation & Infrastructure
    ↓ (typed domain records required)
Phase 3: Domain Layer I — Accounts, Budget & Overview
    ↓ (master account registry required by all other modules)
Phase 4: Domain Layer II — Savings, Investments & Tax
    ↓ (all domain engines required for full projections)
Phase 5: Presentation Layer — App Shell & Module Views
    ↓ (views and write flows are parallel once shell is stable)
Phase 6: Write Flows, Repair & Export
    ↓
Phase 7: Polish & Launch Readiness
    ↓
Phase 8: Out-of-Scope Follow-ups → triaged into the product backlog (closed 2026-07-07)
```

---

## Phase 1 — Foundation & Architecture ✅ (spec `002`, merged PR #15, 2026-06-28; 49/50 tasks)

**Delivered.** The platform floor, built as a **Swift Package** rather than a hand-authored
`.xcodeproj` (the dev environment is CLT-only; module folders map to
`Sources/FinanceWorkspaceKit/{Platform,Parsing,Validation,Domain,Persistence}/`):

- **Storage abstraction**: the `CloudStorageProvider` protocol (`resolveWorkspaceURL` / `syncState`
  / `isAvailable` / per-file state) with `ICloudContainerService` (ubiquity container,
  `NSMetadataQuery`-derived sync states, `NSFileVersion` conflicts) and the DEBUG
  `LocalFolderProvider` (`~/Finance-Dev`). *(An entitlement-free `CloudDocsProvider` for
  direct-download distribution was added later, 2026-07-06 — see Phase 7.)*
- **Workspace lifecycle**: `WorkspaceManager` (resolve → provision-on-first-run → validate required
  paths) + `WorkspaceProvisioner` (16 folders, 46 seed files, the six locked seed accounts,
  `Workspace.md`, schema mirror).
- **Safe-write primitives** every later write composes: `BackupService` (timestamped copies under
  `.finance-meta/backups/`), `FileCoordinatorService` (`NSFileCoordinator` reads/writes),
  `WriteGate` (sync-first write gating over the seven sync states via `SyncStateMapper`).
- **Indexing**: `FileIndexService` (scan/classify/SHA-256/change events), `FileWatcherService`
  (FSEvents, debounced, `.finance-meta/` filtered), `ManifestStore` (device-local regenerable
  manifest in Application Support).
- **Core models** for all domains (single `Account` struct + optional `InvestmentMetadata`;
  `UnifiedTransaction` with multi-entry `group_id`/`group_role`; `AccountGroup` first-class) and
  the `bootstrap-workspace` / `fixture-generate` / `index-check` CLIs.
- **CI from day one**: SwiftLint (Linux) + macOS build/test — earlier than planned.

**Skipped/deferred**: the one unchecked task (T004, iCloud entitlement + signing) landed with the
Phase-5 XcodeGen app target; the signing **run** is backlog **SP-8**. The per-file sync **badge**
design residue is backlog **VD-1**.

### Milestone 1 — ✅ reached

---

## Phase 2 — Parsing, Validation & Infrastructure ✅ (spec `003`, merged PR #16, 2026-06-30; 43/43 tasks)

**Delivered.** Raw files → typed records, plus the validation/repair engine:

- **Parsing**: `CSVParserService` (RFC-4180 tokenizing, header normalization, provenance on every
  record), `CSVSchemaRegistry` over **23 bundled JSON schemas** (`Bundle.module`, mirrored into
  `.finance-meta/schemas/` at bootstrap; `# schema_version: N` comment-row convention),
  `CSVNormalizer` (typed values; a bad field yields a *partial record*, never a dropped row),
  `FrontMatterParser`/`MarkdownParserService`, and `WorkspaceParser` composing them.
- **Validation**: `ValidationEngine` + the 34-rule `RuleCatalog` in the locked
  `VAL-<TIER>-<NNN>` shape (15 file / 11 cross-file / 8 domain; severity + repair class each).
- **Repair**: `RepairService` — create-missing-folder, create-missing-seed-file,
  normalize-header-casing; always preview-diff + backup + `repair-log.csv`, never touching
  manual-only issues.
- `SettingsStore`, `MigrationService` + the `migrate-r6` one-time migration (renames, ledger
  unification, seeding), and the `validate-workspace` / `repair-workspace` CLIs.

**Skipped/deferred**: six catalog rules shipped metadata-only (no predicate — could never fire)
→ backlog **SP-4**; three repair classes (optional-column injection, blank-field normalization,
`WriteGate`-gated repair writes) → backlog **SP-5**. The validation/repair **UI** design landed
with Phase 5 (OOS-3, resolved).

### Milestone 2 — ✅ reached

---

## Phase 3 — Domain Layer I: Accounts, Budget & Overview ✅ (spec `004`, merged PR #18, 2026-07-06; 39/39 tasks)

**Delivered.** The foundational engines over a `ParsedRecord`→typed-entity mapping seam:

- **`AccountEngine`** — the master-registry engine: aggregate/per-account/per-group projections,
  ledger-derived balances + `Liability.principal_balance`, tax-year-anchored YTD net income
  (`gross − expenses − taxes_paid`, transfers excluded, withholding legs as `taxes_paid`), the
  personal-inflow vs **retained-equity** split (business portion), account-rule cash-flow
  projection, multi-employment aggregation.
- **`BudgetEngine`** — plan-vs-actual variance over a budget's allocation scope, partial-aware
  3-month trailing averages ("avg of N mo", never fake zeros), spend-mix, goal contributions.
- **`LinkingEngine` + `OverviewEngine`** — `GoalFundingLink`s, the five-KPI dashboard (Budget/
  Savings/Business live; Investments/Taxes as a **typed "data not available"** state until
  Phase 4), the gap-skipping trailing-6-month MoM panel, aggregated validation issues.
- The expanded seed (16 categories across six groups + default Household budget + canonical
  `account_type` taxonomy) and the `accounts-overview` / `budget-overview` / `overview-dashboard`
  CLIs.

**Skipped/deferred**: investment/reinvested-gain retained equity (needs trades) → backlog
**UV-8**; sleeve-funding links compute but had no consumer → backlog **UV-5**.

### Milestone 3 — ✅ reached

---

## Phase 4 — Domain Layer II: Savings, Investments & Tax ✅ (spec `005`, merged PR #19, 2026-07-01; 52/52 tasks)

**Delivered.** The remaining engines, making all five Overview cards live:

- **`SavingsGoalEngine`** — snapshot-or-ledger-derived progress, gap/months-to-goal, funding links.
- **`PortfolioEngine`** — FIFO tax lots from unified-ledger `type = trade` rows (the former
  investment ledger was absorbed), valuation from latest prices, cost basis + unrealized P/L,
  sleeve drift vs targets, dividends, the Portfolio container above sleeves.
- **`BenchmarkEngine`** — 8 calendar-anchored windows (D…5Y; simple return ≤1Y, CAGR 3–5Y,
  last-close-on-or-before anchoring) as the heat-map model + portfolio sector weights.
- **Tax engines** — `TaxEngine` (per-account taxable income / taxes paid / effective rate, ST/LT
  realized gains), `TaxAdjustmentEngine` (std-vs-itemized with hardcoded 2025/26 tables,
  simplified ~20% QBI, Schedule-C business cross-reference, computed bracket estimate + the
  standard-adjustment **safe write**), `TaxPrepEngine` (fixed checklist + the year-close archive
  **safe write**; `Taxes/archive/` excluded from parsing).
- `LinkingEngine` completion (portfolio→tax, Schedule C), four more CLIs, additive schema
  reconciliations (`trade_type`/`quantity`/`price`, `sleeve_id`, `expected_return_rate`, `apy`).

**Skipped/deferred**: sector-vs-benchmark comparison (needs benchmark sector data — **V2**);
per-account estimated-payment allocation → backlog **UC-1**; the hardcoded tax tables' coverage/
fallback → backlog **SP-3**; the interest-income name heuristic → backlog **SP-2**.

### Milestone 4 — ✅ reached

---

## Phase 5 — Presentation Layer: App Shell & All Module Views ✅ (spec `006`, merged PR #20, 2026-07-05; 68/68 tasks)

**Delivered.** The complete SwiftUI app over live projections — strictly read-only by design
(every write affordance visible-but-disabled until Phase 6):

- **Shell**: `FinanceWorkspaceApp`/`AppState` (@Observable)/`AppRouter`, three-column
  `NavigationSplitView` (248px sidebar, "Finance Dashboard" header → Overview default), global
  issues + sync chips, per-view local actions on the title line, the collapsible right
  `.inspector` (⌥⌘I, six surfaces, closed by default), §17 menu `CommandMatrix`,
  `NSUserActivity` restoration codec.
- **Design system in code**: `DesignSystem/` tokens mirroring `DESIGN.md` 1:1 + the component
  library (KPI card, data table, pie/sparkline/bar/heat-map on Swift Charts, period selector,
  empty states, loading skeleton, provenance labels).
- **All five module view groups** (Overview, Accounts incl. group/account screens with inline
  ledgers, Budget, Savings & Investments incl. the holdings ⇄ heat-map toggle, Taxes incl. the
  three-screen tax IA) with full **KPI → detail → source-file traceability**.
- **The XcodeGen app target** (`App/project.yml`, entitled, CI-built unsigned) — closing the
  deferred Phase-1 entitlement task.
- Verified by boot-against-fixture/empty workspaces, the SC-005 read-only tar-compare proof, and
  engine⇄view parity tests.

**Skipped/deferred**: typed tax-archive read model (raw file previews) → backlog **UV-7**;
`AccountEstimate` surface → backlog **UV-4**; signed-app restoration verification → backlog
**SP-7**; XCUITest → delivered in Phase 7; the Flow 9 human walkthrough → backlog **SP-1**.

### Milestone 5 — ✅ reached

---

## Phase 6 — Write Flows, Repair & Export ✅ (spec `007`, merged PR #21, 2026-07-06; 38/50 tasks + Phase-7 completion)

**Delivered.** The app became writable through **one Kit-level write engine**
(`Persistence/Write/`: `WritePlan`/`WritePlanBuilder`, `WriteService`, `CSVRowSerializer`,
`ReferenceScanner`, `ImportMapper`, `ExportService`, `MultiEntry`) that composes the Phase-1
safe-write primitives — never reimplementing them:

- **Structured add/edit/delete for all 12 row entities** via preview → backup → atomic apply →
  re-index (⌘N, panel-bottom Edit/Delete, in-app Close Tax Year); every apply logged (audit
  trail via the write log + named backups).
- **CSV import** (⇧⌘I): auto-detected column mapping with confirmation, single target account,
  explicit sign convention, month-split into canonical ledgers, duplicate flagging.
- **Delete-with-reference-check** (locked Round-7 "reassign" policy): scan → expand delete +
  reassignments into ONE atomic plan — referenced objects never orphan.
- **Guided repair apply** (⇧⌘R) with post-apply re-validate; **Export Current View** (⌘E,
  CSV with `source_file`/`source_row` provenance); the multi-entry reconciliation +
  atomic group-write/delete engine (unit-tested).

**Skipped/deferred (all finished in Phase 7)**: the multi-entry editor UI, reassignment picker,
Budget-Markdown export button, typed forms, account-edit placement, `transactions.description`
column (OOS-13…18) + the App-target write test suites. **Not delivered anywhere**: the `import-csv`
/ `export-summary` CLI twins → backlog **SP-10**. *(Post-hoc fix, 2026-07-09: brand-new monthly
files created by imports were headerless — caught by the Phase-7 integration tests and fixed via
`FileChange.seedHeader`.)*

### Milestone 6 — ✅ reached

---

## Phase 7 — Polish & Launch Readiness ✅ (spec `008`, PRs #22 + #23, 2026-07-09; 53/56 tasks, 206 tests green)

**Delivered.** Launch hardening plus the write-flow completion:

- **Write experience complete**: top-level Import/Add/Edit enabled and sync-gated (tooltip =
  `WriteGate` reason; the missing Edit-account-group added); the multi-entry
  `TransactionGroupEditor` (paycheck authoring, live reconciliation, whole-group ledger
  edit/delete as atomic plans); the per-collection `ReassignmentPickerView` (apply blocked until
  every collection chooses; unlink only where nullable/list); schema-driven **typed form
  controls** (enum/parent-reference pickers, sign-aware amounts); the optional
  `transactions.description` column + memo-aware dedup; the Budget Markdown export button.
- **Sync & conflicts**: the pick-a-version conflict surface over `NSFileVersion` (keep mine /
  keep iCloud / keep both-as-conflicted-copy), entered from the sync chip; Release Developer-ID
  signing **config** + documented release procedure (two paths: entitled target and the
  SwiftPM/CloudDocs bundle via `scripts/package-release.sh`).
- **Performance & reliability**: the per-domain projection cache (`buildCached`, stat-keyed,
  conservative cross-domain invalidation), the FSEvents watcher finally wired to a debounced
  re-index, the CI `PerformanceHarness` asserting **≤2s cold-launch / ≤5s re-index** on the
  12-month fixture, sparse-data resilience, last-known-valid snapshots ("Stale" chip; a vanished
  workspace root throws rather than blanking the UI).
- **Accessibility & native**: VoiceOver label pass; the computed **WCAG AA contrast audit** with
  token fixes (DESIGN.md v1.3 — `on-accent`, dark `info-soft`, `muted-2` decorative-only);
  Escape-closes-inspector; CSV drag-onto-window import + `CFBundleDocumentTypes`; the full §17
  menu; the **3-step require-iCloud onboarding wizard** (DESIGN.md v1.2) + the entitlement-free
  `CloudDocsProvider` distribution path (§21 amended additively).
- **Test hardening**: the 23-type fixture matrix (valid + 12 exact-rule invalid cases),
  read/write/repair integration suites, the write view-model suites, XCUITest smoke + target,
  `BackupPruneService` (last-10 + 30-day, after write + on launch). The suites' first CI run
  caught and fixed **two shipped engine bugs** (headerless new ledgers; the dead
  savings-progress reference rule) plus a cache symlink bug and a blank-UI-on-missing-workspace
  hazard.

**Residue (all in the backlog)**: **SP-7** signed-app restoration check, **SP-8** the first
signed release (sign+notarize run, two-device Flow 10, release notes — certificate-gated),
**SP-9** execute XCUITest in CI, **VD-3** iconography; transfer authoring → **UV-6**,
delete-inside-edit → **UV-2**.

### Milestone 7 — ✅ reached in code (distributable = SP-8)

---

## Phase 8 — Out-of-Scope Follow-ups ✅ closed (2026-07-07, triaged to the backlog)

The residue phase existed to collect what Phases 1–6 consciously deferred. Every row was verified
against the code (`docs/_notes/phase8-alignment-review.md` — 13/15 aligned, 2 reworded) and
triaged into [`docs/product-backlog.md`](product-backlog.md) with a backlog ID (the OOS-numbered
provenance is preserved in git history + the backlog Source column). In the Growth phase new
residue flows **straight to the backlog** — no successor phase, no separate follow-ups doc.

### Milestone 8 — ✅ reached (triage complete)

---

## Summary Table

| Phase | Focus | Key Deliverable | Prerequisite | Status |
|---|---|---|---|---|
| 1 | Foundation & Architecture | Workspace resolves, files indexed, models defined | — | ✅ merged (PR #15) |
| 2 | Parsing & Validation | All file types parsed, validation engine live | Phase 1 | ✅ merged (PR #16) |
| 3 | Domain I — Accounts, Budget, Overview | Core projections, master account registry | Phase 2 | ✅ merged (PR #18) |
| 4 | Domain II — S&I, Tax | All domain engines functional | Phase 3 (AccountEngine) | ✅ merged (PR #19) |
| 5 | Presentation — Shell & All Views | Full UI connected to domain projections | Phase 3 + 4 | ✅ merged (PR #20) |
| 6 | Write Flows, Repair & Export | App is writable, repair is guided | Phase 5 | ✅ merged (PR #21) |
| 7 | Polish & Launch Readiness | Finish Phase-6 write flows + performance, accessibility, signing, test coverage | Phase 6 | ✅ complete (spec `008`, PRs #22/#23; signed-release run → backlog SP-8) |
| 8 | Out-of-Scope Follow-ups | Engine/read-model + repair-infra residue backlog | Phases 2/4/5 (residue) | ✅ triaged → `docs/product-backlog.md` (2026-07-07) |

---

## Open Decisions (Pre-Build)

All Phase 1 architectural decisions have been locked as of 2026-06-10. See `docs/technical-design.md §21` for the full locked-decision record.

| Decision | Resolution |
|---|---|
| `CloudStorageProvider` protocol surface | Minimum surface confirmed: `resolveWorkspaceURL()`, `syncState`, `isAvailable`. Conflict resolution stays iCloud-specific. |
| Master registry vs investment accounts | Unified `Accounts/accounts.csv` with optional investment columns. No separate `Investments/accounts.csv`. |
| Savings/ and Investments/ folder separation | Keep separate at the file level. |
| Deductions file structure | **Reopened & resolved (Round 6):** renamed to `Taxes/tax-adjustments.csv` with an `adjustment_type` union enum; Tax-adjustment is a first-class object. |
| Round 6 object-model reconciliations | **Resolved (2026-06-23):** kept two-tier `account_group`+`account_type`; `status` canonical (`is_active` derived); categories add `parent_category_id`+`category_group_id`; assets add `security_class`; trades fold into the unified ledger; `adjustment_type` = union enum. |
| Tax year-close trigger | Explicit in-app "Close Tax Year" action only. |
| Right pane default-closed scope | Global — closed by default, opens on main-panel interaction, no section exceptions. |
| iCloud container identifier | `iCloud.com.<org>.OpenFinance` (R8 — corrected from bare `OpenFinance`) |
| Workspace bootstrap seed accounts | Personal bank, personal credit card, business bank, business credit card, savings, investment |
| Default delete behavior when an object is referenced | **Locked Round 7** — reassign: surface referencing rows, present per-collection reassignment picker, write delete + reassignments atomically. See `docs/product-requirements.md §12`. |

---

## Changelog

> The roadmap participates in the same round-numbered refinement loop as the PRD and technical
> design. Rounds are global across all three docs; see `docs/_refinement/r{N}-*` for the source
> review and per-doc update plans.

### Follow-ups doc retired — 2026-07-09
- **`docs/out-of-scope-followups.md` deleted.** In the Growth phase, implementation residue goes
  **straight to `docs/product-backlog.md`** (Source column = source spec + task), so maintaining a
  separate follow-ups doc was redundant. Its open items already carry backlog IDs; the resolved-item
  provenance is preserved in git history, the per-phase MVP delivery records above, and
  `docs/_notes/phase8-alignment-review.md`. Living-doc references were redirected to the backlog
  (`CLAUDE.md` spec-completion step + key docs, `README.md`, the backlog/roadmap process text,
  `docs/_notes/workflow-overview.md`, `docs/test-plans.md`); dated changelog entries below that
  mention the doc are left as historical record.

### V2 exclusions absorbed into the backlog — 2026-07-09
- Every *Out of Scope for v1* row now has an **Under-consideration** backlog entry (**UC-4…UC-20**;
  the three dedicated-screen rows share UC-19). The table gained a Backlog column so the two docs
  stay linked; promotion of any V2 item starts with its PRD amendment per the Growth process.

### MVP record condensed — 2026-07-09 (task lists → prose delivery records)
- **Swept every unchecked checkbox in the MVP section against the delivery + backlog** before
  deleting: one genuine gap surfaced — the never-built `import-csv`/`export-summary` CLI twins →
  new backlog **SP-10**; every other unchecked box was delivered (per-phase banners) or already
  tracked (SP-1…9, UV-1…9, VD-1…5, UC-1…3).
- **All task lists (checked and unchecked) removed** from Phases 1–8; each phase is now a prose
  **delivery record**: what shipped (services/engines/views/CLIs/tests, key mechanisms), what was
  consciously skipped and its backlog/V2 destination, and the milestone verdict. Task-level detail
  remains in git history and `specs/NNN-*/tasks.md`.

### Growth phase entered — 2026-07-09 (roadmap restructured; Phase 7 closed)
- **Project phase → GROWTH.** The roadmap is now a pipeline: a **Growth** section on top (Readying /
  Delivered tables + the backlog→spec process) and the entire Phase 1–8 plan preserved below as the
  **MVP — v1 delivery record**. Forward work is promoted from `docs/product-backlog.md` and shipped
  spec-first; implementation residue flows to `docs/out-of-scope-followups.md` and straight back to
  the backlog (no residue phase).
- **Phase 7 marked COMPLETE / Milestone 7 reached in code** (spec `008-polish-launch`: PR #22 US1 +
  write-flow completion; PR #23 US2–US6 + onboarding/CloudDocs, 206 tests green in CI). Every
  Phase-7 checkbox was synced against the delivery; the three genuine residues moved to the backlog:
  **SP-7** (signed-app restoration check), **SP-8** (first signed release: sign+notarize run,
  two-device Flow 10, release notes), **SP-9** (XCUITest in CI). The remaining open design row
  (iconography) already lived in the backlog as **VD-3**.
- **All other open roadmap material triaged**: the *Open Decisions (Pre-Build)* table was already a
  fully-resolved record (kept as history); Phase 1–6 unchecked boxes are annotated as historical
  plan detail under the MVP banner.
- Doc set updated for the phase shift: `CLAUDE.md` (status, workflow, key docs), the backlog
  (Growth process + SP-8/SP-9), `docs/out-of-scope-followups.md` (residue now flows to the
  backlog), PRD/TDD phase banners, and the project-state memory.

### Phase 8 closed — 2026-07-07 (triaged to the product backlog)
- **Phase 8 marked COMPLETE / Milestone 8 reached**: every Phase-8 row was verified against code +
  key docs (`docs/_notes/phase8-alignment-review.md`, 13/15 aligned, 2 with corrected wording) and
  **migrated into the new [`docs/product-backlog.md`](product-backlog.md)** — a prioritized backlog
  (tiers: *add user value* → *security & performance* ∥ *visual design updates* → *under
  consideration*; effort-ordered within tiers). The two PM-requested enhancements lead as UV-1/UV-2.
- **`docs/project-management.md` renamed to `docs/product-backlog.md`** and rewritten: the stale
  open items were closed against the repo first (onboarding/loading/shell design `[DECIDE]`s
  shipped in 006/009; `[FIX-C6/M1/M6]` overtaken by the R7 lean refactor; 5 of 6 Phase-7
  `[DECIDE]`s resolved by spec 008) — remaining residue became backlog rows (VD-1, VD-3, UC-2,
  UC-3). Cross-references updated in `CLAUDE.md` and `docs/out-of-scope-followups.md`; the
  follow-ups doc now records each item's backlog ID and stays as the provenance record.

### Backlog addition — 2026-07-07 (PM request)
- **Phase 8 gained a *PM-requested enhancements* grouping** with its first row: manual
  drag-re-ordering of accounts and account groups in the sidebar "Account groups" section,
  persisted as an optional `sort_order` column on `accounts.csv`/`account-groups.csv`
  (plain-files-first; additive/non-breaking) rather than a device-local preference.
- **Second row: Delete inside the edit modal** for accounts, account groups, and categories —
  `EntityEditForm` gains a Delete action (destructive, "delete inside the edit flow" per the
  locked convention) routed through the existing delete-with-reference-check/reassignment path;
  overlaps OOS-14, pairs with OOS-17.

### Backlog sync — 2026-07-06 (spec 002–008 review + code audit; branch `009-out-of-scope-followups`)
Not a refinement round — a Phase-8 backlog expansion after reviewing the task state of specs
002–008 and auditing the app source. Canonical per-item detail: `docs/out-of-scope-followups.md`.

- **Spec review**: all residue from specs `002`, `007`, and `008` was already tracked (Phase 7 /
  OOS-1, OOS-13…18); specs `004`–`006` residue was already in Phase 8 (OOS-4/5/7/8). The one gap:
  spec `003`'s three partially-delivered rule tasks left **six registered-but-inert validation
  rules** (catalog metadata, no predicate) → new **OOS-19**.
- **Code-audit findings** (new): transfer authoring missing from `TransactionGroupEditor`
  (**OOS-20**), generic current-view export not wired (**OOS-21**), per-file sync states never
  reach `WriteGate` in the app write path (**OOS-22**), hardcoded 2025/2026 tax tables with a
  silent latest-year fallback (**OOS-23**, ties to the open Phase-4 `[DECIDE]`), and the
  interest-income category-name heuristic in `TaxEngine` (**OOS-24**).
- Phase 8 gained a *Code-audit findings* grouping and a *QA residue* row (the spec-`006` Flow 9
  manual demo pass, previously tracked only in `docs/test-plans.md` / the OOS doc); the spec-`003`
  grouping widened to *Validation, repair & write-infra residue* to hold OOS-19/OOS-22.

### Build-status sync — 2026-07-06 (Phases 4–6 merged; Phase 7 active; Phase 8 added)
Not a refinement round — a doc-to-repo alignment recorded after Phases 4–6 land on `main`.

- **Phases 4, 5, and 6 marked COMPLETE and merged** (PRs #19/#20/#21). Phase 4 (`005`) and Phase 5
  (`006`) status banners flipped from "🟡 pending CI + merge" to "✅ merged"; a **new Phase 6 (`007`)
  status banner** records the writable-app delivery (one Kit-level write engine composing the
  Phase-1 safe-write primitives; US1/US2/US4/US5/US6 shipped + CI-tested; US3 multi-entry engine
  shipped). Milestone 6 marked reached.
- **Phase 6 UI residue captured**: multi-entry editor (OOS-16), reassignment picker (OOS-17), Budget
  Markdown export button (OOS-18), D10 typed forms (OOS-13), account-edit placement (OOS-14),
  optional `transactions.description` column (OOS-15) — initially routed to Phase 8, then **moved to
  Phase 7** (see below). The `007` series was renumbered OOS-13…OOS-18 in
  `docs/out-of-scope-followups.md` to end the collision with the `006` series OOS-7/8/9.
- **Phase 7 (Polish & Launch Readiness) rewritten for current state**: added a 🔵 ACTIVE banner
  (branch `008-polish-launch`), annotated tasks already satisfied by Phases 1–6 (✅ domain-engine
  unit tests, ✅ `fixture-generate`; 🟡 keyboard nav, command matrix, `NSUserActivity` codec), and
  added an explicit **Packaging & Signing** subsection (code-sign + notarize the app target — OOS-1;
  real iCloud sync on a signed build) plus an XCUITest item.
- **New Phase 8 — Out-of-Scope Follow-ups**: a post-v1 backlog phase mirroring
  `docs/out-of-scope-followups.md` (write-flow UI residue, engine/read-model gaps, repair/write-infra
  residue), with pure-V2 items (sector-vs-benchmark data, live price ingestion) explicitly kept out.
- **Unfinished Phase-6 write-flow work moved from Phase 8 into Phase 7** (new *Complete Phase 6
  write flows* subsection): OOS-13…OOS-18 (multi-entry editor, reassignment picker, Budget-MD export
  button, typed forms, account-edit placement, `transactions.description` column) + the deferred
  App-target write test suites. Phase 8 now holds only the engine/read-model + repair-infra residue
  and pure-V2 items; the Phase 6/7/8 banners, Milestone 6, and summary table were resynced.
- **Phase 7 gained a "Write-affordance enablement" task group (do-first)** after finding that the
  running app still shows the **top-level Import/Add/Edit buttons disabled** — Phase 6 shipped the
  write engine + ⌘N + inspector Edit/Delete + preview/form views but never converted the module
  page-title `LocalAction.writeStub(...)` placeholders (hardcoded `isEnabled: false`) to live
  handlers. Captured in the Phase 7 status banner + a concrete per-view task list. (Overlaps and
  subsumes OOS-14, the dedicated-screen account-edit placement.) The same task group adds the
  **missing "Edit account group" action** — `AccountGroupDetailView` has no group-edit affordance at
  all (absent, not just disabled), though the engine + `EntityEditForms` already support it.
- **Dependency overview, summary table, and status column** updated; the top-of-doc "Last updated"
  line now reflects Phases 1–6 complete.

### Build-status sync — 2026-06-30 (Phase 3 build complete on branch)
Not a refinement round — a doc-to-repo alignment recorded as the Phase 3 implementation lands on
`004-domain-accounts-budget-overview` (pending CI + merge).

- **Phase 3 marked BUILD COMPLETE on branch** (spec `004-domain-accounts-budget-overview`, 39/39
  tasks; **Milestone 3** reached). Added a 🟡 status banner at the top of Phase 3 and annotated the
  Milestone 3 callout.
- **Domain Layer I delivered:** record-mapping seam (`ParsedRecord`→typed entities), `AccountEngine`,
  `BudgetEngine`, `LinkingEngine`, `OverviewEngine`, expanded seed (16 categories / 6 groups +
  default Household budget), and the `accounts-overview` / `budget-overview` / `overview-dashboard`
  CLIs. Engine math (retained-equity split, withholding-as-taxes, partial trailing averages,
  gap-skipping MoM, stubbed Investments/Taxes cards) verified via the CLIs; full test + lint gate
  runs in macOS CI.
- **`[FIX-C2]` retired** (roadmap Phase-3 dependency note already carried the correct paths) and the
  Phase-3 product `[DECIDE]`s resolved in the spec; `docs/project-management.md` updated.
- **Living docs updated:** `docs/out-of-scope-followups.md` (OOS-4/5/6 — Phase-4 retained equity &
  sleeve links, Phase-5 UI + estimated-rate) and `docs/test-plans.md` (projection CLIs now testable).
- **Next:** push → CI → PR/merge; then **Phase 4 (Domain Layer II — Savings, Investments & Tax)**.

### Build-status sync — 2026-06-30 (Phase 2 complete & merged)
Not a refinement round — a doc-to-repo alignment recorded as Phase 2 completes.

- **Phase 2 marked COMPLETE** (merged to `main`, PR #16; spec `003-parsing-validation`, all 43
  tasks; Milestone 2 gate confirmed at T043). Added a status banner at the top of Phase 2.
- **Parsing + Validation layer delivered:** `CSVParserService` / `CSVSchemaRegistry` /
  `CSVNormalizer` / `FrontMatterParser` / `MarkdownParserService` / `WorkspaceParser`,
  `ValidationEngine` + `RuleCatalog` (34 rules: 15 file / 11 cross-file / 8 domain), `RepairService`,
  `SettingsStore`, `MigrationService`, and the `validate-workspace` / `repair-workspace` /
  `migrate-r6` CLIs.
- **Schemas bundled:** 23 canonical JSON schemas live in
  `Sources/FinanceWorkspaceKit/Resources/Schemas/` (loaded via `Bundle.module`) and mirror into the
  workspace `.finance-meta/schemas/` at bootstrap.
- **Project-management sync:** the two partially-resolved Phase 2 `[DECIDE]`s (CSV spec gaps,
  validation rule catalog) and all five `R6-M1…M5` `[FIX]`s retired; item-count table updated.
- **Phase 3 (Domain Layer I — Accounts, Budget & Overview)** is the next phase — not yet started.

### Build-status sync — 2026-06-28
Not a refinement round — a doc-to-repo alignment recorded as Phase 2 begins.

- **Phase 1 marked COMPLETE** (merged to `main`, PR #15; spec `002-foundation-architecture`, 49/50
  tasks). Added a status banner at the top of Phase 1.
- **Packaging reality recorded:** foundation built as a **Swift Package** (`FinanceWorkspaceKit`
  library + `FinanceWorkspaceApp`/`bootstrap-workspace`/`fixture-generate`/`index-check`
  executables), not a hand-authored `.xcodeproj`; module folders map to
  `Sources/FinanceWorkspaceKit/{Platform,Domain,Validation,Persistence,Parsing}/`. The "Xcode
  Project Setup" tasks were realized via SwiftPM.
- **macOS CI landed early:** `ci-macos.yml` (`swift build`/`swift test`) shipped in Phase 1
  alongside the Linux SwiftLint runner; supersedes the "full Mac build CI deferred to Phase 5"
  note.
- **One Phase 1 item deferred:** the iCloud ubiquity-container entitlement + dev code signing
  (needs the Xcode app target).
- **Phase 2 started** on branch `003-parsing-validation` (spec `specs/003-parsing-validation`).

### Round 8 — 2026-06-26
Source: `docs/_refinement/r8-review.md` (foundation hardening — Phase 1–2 dev-env / storage / sync)

- **New Phase 0 sub-track** (env bootstrap: entitlement, DEBUG local-folder provider, `fixture-generate`, CI smoke test for dual-mode workspace resolution, JSON schema authoring).
- **Phase 1 Platform tasks** reworded: `ICloudContainerService` (NSMetadataQuery sync state, `NSFileVersion` conflicts, `iCloud.<bundle-id>` ID), `FileWatcherService` (NSMetadataQuery + FSEvents), `ManifestStore` (device-local Application Support location).
- **Phase 1 Product tasks** for entitlement / 7 sync states / manifest shape marked resolved (R8).
- **Core Data Models**: removed `OwnerDistribution`; `Account` = single struct + optional `InvestmentMetadata?`.
- **Phase 2**: schema_version comment-row + JSON schemas as source of truth; sign-flip = explicit per-import declaration; validation rule-catalog shape + classification defaults adopted; `goals.csv status ∈ {active, archived}`; `savings-goal-contributions.csv` removed.
- **Spec-review follow-up (2026-06-26):** Phase 1 Core Data Models gained `AccountGroup` (first-class R6 object, `account_group_id` FK) and the `BusinessMonthlySummary` cross-domain projection. Schema-count wording reconciled ("28" → one schema per managed file type). Surfaced during the `specs/002-foundation-architecture` review.

### Round 7 — 2026-06-24
Source: `docs/_refinement/r7-review.md` (MVP prep — doc-sync debt + direction decisions B1–C5)

**Section A — doc-sync debt:**
- Out of Scope: added "Live price ingestion strategy" as an explicit V2 tracked item (A5)
- Phase 2: R6 migration tasks promoted to explicit `[FIX]` items in `docs/project-management.md` (`R6-M1` through `R6-M5`); prototype path-fix task added as `[FIX – R7-P1]`
- Phase 6 Design: added prototype update task for write/edit flow demos
- `docs/technical-design.md` refactored to a lean overview with links to `docs/architecture/` (A3)
- `docs/architecture/data-pipelines.md` §3 adds four ingestion pipeline diagrams (A4)
- `prototype/data.js` stale file paths corrected (A2)
- `docs/project-management.md`: resolved items C1, C5, S8 retired; R6 migration tasks added (A1)

**Section B/C — direction decisions:**
- Open Decisions: delete-on-reference locked as **reassign** (B1); Business module locked as **group type under Accounts** — no standalone BusinessEngine (B3); Markdown viewer/editor locked as **V2** (B4)
- `docs/product-requirements.md`: §4 Markdown V2, §8 tax scope guardrail, §12 reassign delete policy, NFR Performance M1+ target, NFR Reliability sync-first write safety (C1)
- `docs/architecture/core-domain.md §3`: sync-first write gate documented on ICloudContainerService; Business module note updated to resolved
- `docs/technical-design.md §21`: locked decisions added for B1/B3/B4/C1/C2/C5
- `docs/project-management.md`: [FIX-S1], [FIX-C3], [FIX-S2] retired

### Round 6 — 2026-06-23
Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & IA); update plan `docs/_refinement/r6-update-product-roadmap.md`

- Phase 1: Core Data Models and bootstrap updated for the renamed + new files (account-groups, liabilities, assets, portfolios, budget-allocations, tax-adjustments, tax estimates/documents) and the multi-entry transaction columns
- Phase 2: added multi-entry group validation; added `migrate-r6.swift` (preview-able schema migration that also folds `Investments/transactions.csv` into the unified ledger)
- Phase 3: AccountEngine derives liability balances; BudgetEngine resolves a Budget's scope over its allocations
- Phase 4: PortfolioEngine gains the Portfolio container; investment trades fold into the unified ledger; `TaxAdjustmentEngine` replaces `DeductionEngine` (adds tax-estimates + tax-documents)
- Phase 5: account screens surface assets and liabilities; Portfolio views; new multi-entry transaction editor
- Phase 6: multi-entry groups written atomically
- Open Decisions: reopened+resolved the deductions-file decision; recorded the Round 6 reconciliation resolutions *(delete-on-reference locked Round 7: reassign)*
- Overrides the r5 object-model audit where they differ (Portfolio not Strategy, `account_group_id` not `group_id`, no group nesting) — r6-review takes priority

### Round 5 — 2026-06-15
Source: `docs/_refinement/r5-review.md` (third prototype review — functional details); update plan `docs/_refinement/r5-update-product-roadmap.md`

- Out of Scope: added contextual filter bar (→ V2)
- Phase 5 App Shell: Overview is the default landing screen via the sidebar header ("Finance
  Dashboard"), not a nav item; issues chip moved to the global header; local-actions row moved to
  the page-title line; FilterBarView deferred to V2
- Phase 5 Accounts: `AccountGroupDetailView` shows individual-account cards + inline ledger (no
  sub-tabs); `AccountDetailView` is the per-account screen reached by tapping account cards
- Phase 5 Budget: Spend Mix / Spending Variance panels set to 50/50
- Phase 5: chart components implemented on Swift Charts (real charts, not placeholder SVGs)
- Phase 6: every user-addable entity now supports delete (with a delete-with-reference-check
  rule) in addition to add/edit; added the edit/delete UI placement convention
- Open Decisions: added default delete-on-reference behavior
- Deeper Budget⇄Strategy object model deferred to a future round (`docs/_notes/object-model-audit.md`)

### Baseline — 2026-06-11
- Roadmap authored reflecting all decisions through Round 3 (prototype review Round 1, the
  multi-cloud direction of Round 2, and the sidebar-and-locks direction of Round 3). These rounds
  are baked into the initial phase plan rather than applied as per-round deltas, so there are no
  `r1`–`r3` roadmap update plans.

### Round 4 — 2026-06-12
Source: `docs/_refinement/r4-review.md` (second prototype review); update plan `docs/_refinement/r4-update-product-roadmap.md`

- Out of Scope: added goal lifecycle states (active/archived), dedicated sleeves screen, dedicated
  benchmark screen, and dedicated deductions screen as V2 items; noted that estimated payments and
  gains & income stay in v1, surfaced within Current Tax Year
- Phase 4 Product (Taxes): added the three-screen consolidation note (Current Tax Year, Prep
  Checklist, Tax Archive)
- Phase 4 Design: replaced the separate Assets / Benchmark heat map / Sleeve detail tasks with a
  single holdings-focal Portfolio overview task (standard ⇄ heat-map toggle, sleeve table at
  bottom); merged Tax overview, Deductions, and Estimated payments design tasks into one Current
  tax year task; expanded the prep checklist task to a full-width educational screen
- Phase 4 Dev: `SavingsGoalEngine` noted as having no goal lifecycle states (no status branching)
- Phase 5: `AssetsView`, `SleeveDetailView`, and `BenchmarkView` replaced by a single
  `PortfolioView`; `TaxOverviewView`, `TaxDeductionsView`, and `EstimatedPaymentsView` replaced by
  a single `CurrentTaxYearView`; `GoalsListView` is a flat list; fixed stale `SavingsInvestmentsView`
  sub-navigation (now Overview, Goals, Portfolio)
