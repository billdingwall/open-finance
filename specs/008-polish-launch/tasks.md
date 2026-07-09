---
description: "Task list for Polish & Launch Readiness (Phase 7)"
---

# Tasks: Polish & Launch Readiness (Phase 7)

**Input**: Design documents from `specs/008-polish-launch/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: INCLUDED — the spec (US6, FR-023/024) and plan mandate Swift Testing + XCUITest suites that
run in macOS CI. The CLT-only dev box runs `swift build`; `swift test` + `swiftlint --strict` +
XCUITest run in CI (per CLAUDE.md testing protocol). Signing + two-device iCloud sync are **manual**
on real hardware.

**Organization**: Grouped by user story (US1–US6, priority order). **US1 is already delivered on this
branch** — its implementation tasks are checked `[X]`; only its tests remain.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no incomplete dependency)
- **[Story]**: US1–US6; Setup/Foundational/Polish carry no story label
- All paths are repo-relative

---

## Phase 1: Setup (scaffolding)

- [X] T001 [P] Scaffold `Sources/FinanceWorkspaceApp/UI/Write/TransactionGroupEditor.swift` and
  `Sources/FinanceWorkspaceApp/UI/Write/ReassignmentPickerView.swift` (file headers only) —
  superseded by full implementations (T018/T021); both files exist
- [X] T002 [P] Scaffold `Sources/FinanceWorkspaceApp/UI/Onboarding/OnboardingView.swift` and
  `Sources/FinanceWorkspaceApp/UI/Shell/ConflictResolutionView.swift` (file headers only) —
  superseded by full implementations: `OnboardingView.swift` (T045, delivered on this branch)
  and `ConflictResolutionView.swift` (T031, 2026-07-07).
- [X] T003 [P] Scaffold `Sources/FinanceWorkspaceKit/Persistence/Write/BackupPruneService.swift`
  (implemented fully with T046)
- [X] T004 [P] Add the `backup-prune` executable target (`Sources/backup-prune/main.swift`) and
  register it in `Package.swift`
- [X] T005 [P] Scaffold the XCUITest target `Tests/FinanceWorkspaceUITests/` and add it to
  `App/project.yml` (macOS-runner only) ✓ 2026-07-07 — `bundle.ui-testing` target + scheme test
  action; delivered with the T051 smoke suite rather than as an empty scaffold
- [X] T006 [P] Scaffold App-target write view-model test stubs in `Tests/FinanceWorkspaceAppTests/`:
  `WritePreviewViewModelTests.swift`, `ImportViewModelTests.swift`, `ReassignmentViewModelTests.swift`,
  `RepairApplyTests.swift` — superseded: the target already existed; suites are being written in
  full (T014/T020/T028/T050) rather than stubbed
- [X] T007 [P] Scaffold the performance measurement harness
  `Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift` — superseded by the full T034 harness

---

## Phase 2: Foundational (shared prerequisites)

**⚠️ Blocks the test-bearing stories.** No engine changes — the Phase-6 write engine + safe-write path
are merged and remain the sole mutation path.

- [X] T008 Confirm the merged `Persistence/Write/*` engine + `WriteService` safe-write path build and
  are unchanged; `swift build` green as the baseline for this phase ✓ 2026-07-07
- [X] T009 Extend the temp-workspace test helper (`Tests/FinanceWorkspaceKitTests/Fixtures/FixtureWorkspace.swift`
  + `Tests/FinanceWorkspaceAppTests/AppFixtures.swift`) to seed **all** managed file types — shared by
  the US6 fixture matrix, the integration tests, and the App write VM suites ✓ 2026-07-07
  (`FixtureWorkspace.full()` — all 23 managed types incl. the `description` ledger column;
  `AppFixture.full()` layered over `standard()` so existing assertions stay stable)

**Checkpoint**: fixtures + baseline build ready — stories can proceed.

---

## Phase 3: User Story 1 — Enable visible write actions (Priority: P1) 🎯 DELIVERED

**Goal**: Every visible write action operable and sync-gated; the missing Edit-account-group added.

**Independent Test**: From the visible toolbar/sidebar/empty states alone, add a group/account/goal/
category, import, and edit an account + account group — each opens the flow and applies with a preview
+ backup; no permanently-disabled write button remains.

### Implementation (delivered — commit on branch)

- [X] T010 [US1] `writesEnabled`/`writeGateReason` + per-entity add/edit helpers + `presentEditEntity`
  / `dataRowNumber` in `Sources/FinanceWorkspaceApp/AppState+WriteFlows.swift`
- [X] T011 [US1] `LocalAction.disabledReason` + `.write` factory; remove `writeStub`; disabled tooltip
  = sync reason in `Sources/FinanceWorkspaceApp/UI/Shell/PageTitleActionsView.swift`
- [X] T012 [US1] Wire live sync-gated actions in `AccountsView`, `AccountGroupDetailView`
  (**+ new Edit account group**), `AccountDetailView`, `BudgetCategoriesView`, `SavingsInvestmentsView`,
  `GoalDetailView`
- [X] T013 [US1] Enable sidebar **New group** (`NavigationSidebarView`) + empty-state CTAs
  (`EmptyStateView` + `ctaDisabledReason`; Accounts/Budget/Goals/Budget-overview CTAs)

### Tests for User Story 1

- [X] T014 [P] [US1] `WritePreviewViewModelTests` — apply → re-index, cancel no-op, `driftDetected` →
  re-preview in `Tests/FinanceWorkspaceAppTests/WritePreviewViewModelTests.swift` ✓ 2026-07-07
  (3 tests; runs in macOS CI — CLT box cannot compile test targets)
- [X] T015 [P] [US1] Smoke test asserting **no module view ships a permanently-disabled write button**
  (SC-001) in `Tests/FinanceWorkspaceAppTests/WriteAffordanceSmokeTests.swift` ✓ 2026-07-07
  (factory invariants + structural source scan for `writeStub`/`isEnabled: false`)
- [X] T016 [US1] Tick the delivered write-affordance-enablement + Edit-account-group tasks in
  `docs/product-roadmap.md` Phase 7 ✓ 2026-07-07 (also ticked delivered OOS-15/OOS-18 rows)

**Checkpoint**: US1 locked against regression by tests.

---

## Phase 4: User Story 2 — Finish the deferred write flows (Priority: P2)

**Goal**: Multi-entry editor, reassignment picker, Budget Markdown export, typed forms, and the
optional `description` column.

**Independent Test**: Author a balanced paycheck group (one month) and apply atomically; delete a
referenced category choosing a target per collection; export a Budget month to Markdown; edit a goal
via typed controls; import a memo CSV and see it retained + used for dedup.

### Multi-entry editor (D1 · OOS-16)

- [X] T017 [P] [US2] Extend `MultiEntryWriteTests` — added the grossNet paycheck one-file/3-leg write
  case (balanced one-file write + whole-group delete already covered) in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/MultiEntryWriteTests.swift`
  (`cross-month` isn't representable — `MultiEntry.plan` takes a single month)
- [~] T018 [US2] Build `TransactionGroupEditor` — **paycheck (grossNet)** flow shipped (author gross +
  N withholdings + net in one month, live reconciliation bar, Add blocked until balanced → one
  `FileChange` via `MultiEntry.plan`), reached by ⇧⌘G "New Paycheck Group…" + sheet in
  `Sources/FinanceWorkspaceApp/UI/Write/TransactionGroupEditor.swift`. **Transfer (balanced
  debit/credit) deferred** — the shipped `MultiEntryLeg.Role` enum lacks credit/debit, so a transfer
  would emit a schema-invalid `group_role`; needs a small additive engine change (follow-up).
- [X] T019 [US2] Wire **whole-group** edit/delete from the ledger in
  `Sources/FinanceWorkspaceApp/UI/Shared/LedgerTableView.swift` and
  `Sources/FinanceWorkspaceApp/UI/Accounts/AccountGroupDetailView.swift` ✓ 2026-07-07 — group-row
  context menu (Edit for paycheck-shaped groups → editor EDIT mode → one atomic delete+add
  `FileChange` via `presentGroupRewrite`, keeping the `group_id`; Delete → `MultiEntry.deletePlan`).
  All ledger surfaces share `LedgerTableView`, so `AccountGroupDetailView`/`AccountDetailView`/
  Budget inherit the one implementation

### Reassignment picker (D2 · OOS-17)

- [X] T020 [P] [US2] `ReassignmentViewModelTests` — apply blocked until every group chosen,
  self-deleted target rejected in `Tests/FinanceWorkspaceAppTests/ReassignmentViewModelTests.swift`
  ✓ 2026-07-07 (5 tests incl. unlink-only-when-nullable/list + unresolvable-group blocking)
- [X] T021 [US2] Build `ReassignmentPickerView` (one picker per collection; "leave unlinked" only when
  nullable; list replace/remove) in `Sources/FinanceWorkspaceApp/UI/Write/ReassignmentPickerView.swift`
  ✓ 2026-07-07 (testable `ReassignmentModel` + sheet; unresolvable required groups block with guidance)
- [X] T022 [US2] Replace `requestDelete`'s first-available-target default with the picker selection in
  `Sources/FinanceWorkspaceApp/AppState+WriteFlows.swift` ✓ 2026-07-07 (`pendingReassignment` sheet →
  `applyReassignments` builds the atomic plan incl. `WritePlan.reassignments` records)

### Budget Markdown export (D3 · OOS-18)

- [X] T023 [US2] Add the "Export summary (Markdown)" action → `ExportService.budgetSummaryMarkdown` via
  a save panel in `Sources/FinanceWorkspaceApp/UI/Budget/BudgetOverviewView.swift`

### Typed entity forms (D4 · OOS-13)

- [X] T024 [US2] Add the `(file, column)` → control map (grouped parent pickers, sign-aware amount
  fields, enum pickers sourced from `CSVSchemaRegistry`) in
  `Sources/FinanceWorkspaceApp/UI/Write/EntityEditForms.swift` ✓ 2026-07-07 — schema-driven typed
  controls: enum pickers (schema `values`), parent-reference pickers over live workspace ids with
  display names (schema `references`), `SignAwareAmountField` (debit/credit + magnitude, locked
  sign convention), boolean toggles, date/decimal numeric fields; free-text fallback so unknown
  columns never block editing

### `transactions.description` column (D5 · OOS-15)

- [X] T025 [P] [US2] Tests — description retained + synonym auto-detect + differing-description
  disambiguation + absent-safe backward-compat in
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/ImportMapperTests.swift`
- [X] T026 [US2] Add the **optional** `description` column to
  `Sources/FinanceWorkspaceKit/Resources/Schemas/transactions.schema.json` (schema loaded via
  `Bundle.module`; no `schema_version` bump, no migration — validate-workspace confirmed clean)
- [X] T027 [US2] Map memo/payee synonyms → `description`, retain it on rows, and make the duplicate
  key date+amount+description (fall back to date+amount when either side lacks a description) in
  `Sources/FinanceWorkspaceKit/Persistence/Write/ImportMapper.swift`; seed header updated in
  `AppState+WriteFlows.swift`
- [X] T028 [P] [US2] `ImportViewModelTests` — required-unmapped blocks advance, duplicates
  default-excluded, target account required in `Tests/FinanceWorkspaceAppTests/ImportViewModelTests.swift`
  ✓ 2026-07-07 (3 tests; target-account requirement asserted via account-scoped stamping + dedup)

**Checkpoint**: the writable app is feature-complete; US1 still works.

---

## Phase 5: User Story 3 — Signed, installable, iCloud-syncing build (Priority: P2)

**Goal**: Developer ID signed + notarized build; manual pick-a-version conflict resolution.

**Independent Test**: Install a signed build on two Macs; edit on A → appears on B; force a conflict →
"conflict detected" → pick a version → resolves with no data loss.

- [X] T029 [US3] Configure Developer ID Application signing + hardened runtime + notarization settings
  in `App/project.yml` ✓ 2026-07-07 — hardened runtime was already on; added the Debug(ad-hoc)/
  Release(`Developer ID Application` + `--timestamp`, manual style) config split. CI unaffected
  (`CODE_SIGNING_ALLOWED=NO`). The actual signed/notarized run remains a developer-machine action
  (needs the Developer ID certificate)
- [X] T030 [US3] Document the `xcodegen generate` → build → `notarytool submit` → `stapler` release
  step in `docs/_notes/running-and-testing.md` ✓ 2026-07-07 (§7 — both paths: entitled Xcode
  target and the SwiftPM CloudDocs bundle via scripts/package-release.sh)
- [X] T031 [US3] Build the conflict-resolution surface (list `NSFileVersion` alternatives; keep-mine /
  keep-iCloud; `removeOtherVersions`; re-index) in
  `Sources/FinanceWorkspaceApp/UI/Shell/ConflictResolutionView.swift` + `AppState` ✓ 2026-07-07 —
  `AppState+Conflicts.swift` (scan + resolve over the Kit `ConflictResolver`, which already owned
  the plan/apply incl. keep-both conflicted-copy siblings) + the pick-a-version sheet
- [X] T032 [US3] Surface the per-file "conflict detected" entry point from the header sync chip →
  conflict surface in `Sources/FinanceWorkspaceApp/UI/Shell/` (header) ✓ 2026-07-07 — the sync
  chip is now a button ("Conflict — click to resolve") opening the sheet; harmless empty state
  in any other sync state
- [X] T033 [US3] Record the manual two-device sync + conflict verification protocol in
  `docs/test-plans.md` ✓ 2026-07-07 (Flow 10 — 7 steps incl. all three resolution choices +
  the conflict write-gate check; execution still needs the signed build + two Macs)

**Checkpoint**: a real signed build syncs across devices and resolves conflicts safely.

---

## Phase 6: User Story 4 — Fast & resilient (Priority: P3)

**Goal**: Meet ≤2s/≤5s; stay responsive; never crash or mix stale/fresh on sparse data.

**Independent Test**: Harness proves ≤2s cold-launch / ≤5s re-index on the 12-month fixture; external
edits keep the UI interactive; sparse fixtures render designed empty states.

- [X] T034 [P] [US4] Performance harness asserts cold-launch → first-projection ≤ 2s and full re-index
  ≤ 5s on the 12-month fixture in `Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift`
  ✓ 2026-07-07 — 12-month ×~115-rows/month synthetic workspace; measures the exact Kit pipeline
  `ProjectionStore.buildSync` runs (parse → engines → dashboard) with `ContinuousClock`; budget
  asserts fail CI on regression
- [X] T035 [US4] Hash-keyed per-domain projection cache (recompute only changed domains, keyed by
  `ManifestStore` hashes) in `Sources/FinanceWorkspaceApp/ProjectionStore.swift` ✓ 2026-07-07 —
  `buildCached` + `DomainKeys`: per-domain stat digests (path·size·mtime; **deviation**: stat keys
  instead of ManifestStore SHA-256 — the indexer isn't in the reindex path and content hashing
  would read every byte, which is the cost being avoided). Conservative cross-domain invalidation
  (ledger feeds all; taxes also on accounts/budget/investments); same-day + same-settings guard;
  parse stays global (context must be current); dashboard always recomputes (aggregates issues).
  Covered by `ReliabilityTests.unchangedWorkspaceReusesCachedDomainProjections`
- [X] T036 [US4] Debounce `FileWatcherService` bursts into one re-index in
  `Sources/FinanceWorkspaceKit/Platform/FileWatcherService.swift` ✓ 2026-07-07 — pre-check found
  the service **already debounced** (0.3s coalescing + `.finance-meta/` filter, Phase 1); the real
  gap was that **no app code started a watcher** (external edits needed manual ⌘R). Wired:
  `AppState.startWatchingIfNeeded()` (idempotent, on first successful reindex) → debounced
  `reindex()`
- [X] T037 [US4] Lazy-load module views + audit parse/validate off the main actor in
  `Sources/FinanceWorkspaceApp/` (routing) / `ProjectionStore` ✓ 2026-07-07 — **verified already
  satisfied**: `ProjectionStore.build` is `nonisolated async` (runs off the main actor under
  Swift 6; documented in the type header) and `ModuleContainerView`'s route switch instantiates
  only the active branch (SwiftUI lazy view builders). No code change needed
- [X] T038 [P] [US4] Reliability tests — last-known-valid projection served during re-index (no
  stale/fresh mix); sparse/empty/partial-column fixtures never crash in
  `Tests/FinanceWorkspaceKitTests/Unit/EdgeCaseTests.swift` ✓ 2026-07-07 —
  `SparseDataResilienceTests` appended there (4 tests: empty / header-only / month gaps /
  partial+bad rows); the last-known-valid + cache-contract half lives in the App target
  (`Tests/FinanceWorkspaceAppTests/ReliabilityTests.swift`, 2 tests) since it exercises
  `AppState.reindex`

**Checkpoint**: performance budget met; resilient under real data.

---

## Phase 7: User Story 5 — Accessible, native & polished (Priority: P3)

**Goal**: Keyboard + VoiceOver + WCAG AA; restoration; drag-drop; full menu; require-iCloud onboarding.

**Independent Test**: Navigate every view by keyboard; VoiceOver + contrast pass in light/dark;
relaunch restores; drag a CSV imports; iCloud-off launch shows enable-iCloud + retry.

- [X] T039 [P] [US5] VoiceOver `.accessibilityLabel` audit across interactive elements in
  `Sources/FinanceWorkspaceApp/UI/` ✓ 2026-07-07 — baseline coverage existed (charts, KPI cards,
  chips, sidebar); the audit added labels to the remaining unlabeled interactives: ledger
  entry/leg rows (title·date·amount·leg-count) and every `labelsHidden()` picker (typed entity
  forms, reassignment picker, import mapping/account, onboarding). VoiceOver runtime pass rides
  the manual Flow 9 walkthrough
- [X] T040 [P] [US5] WCAG AA contrast audit of `DesignSystem` tokens (light + dark); fix any failure
  via `design-token-sync` in `Sources/FinanceWorkspaceApp/DesignSystem/` ✓ 2026-07-07 — computed
  every used pair (DESIGN.md v1.3): **fixed** dark `info-soft` #0e2747→#081a30 (was 4.11:1), new
  `on-accent` token so dark primary buttons use near-black text (white was 3.23:1), and `muted-2`
  restricted to decorative use (≤2.6:1 in light — six meaningful-text sites moved up to `muted`).
  Marginals documented (light muted-on-window 4.30, dark accent-as-text 4.38). Prototype CSS is
  light-only, so only `--on-accent` needs adding at the next prototype sync
- [X] T041 [US5] Keyboard-navigation audit (sidebar → main → inspector; arrows/Return/Escape) across
  `Sources/FinanceWorkspaceApp/UI/Shell/` + tables ✓ 2026-07-07 — code audit: native
  List/NavigationSplitView arrow-nav + 24 keyboard affordances (⌥⌘I, sheet ⏎/⎋ defaults) were in
  place; added the missing **Escape-closes-detail-pane** (`onExitCommand` on the shell). Full
  interactive verification rides the manual Flow 9 pass
- [ ] T042 [US5] Verify `NSUserActivity` restoration end-to-end in the **signed** app; restore to the
  nearest valid context when the prior entity is gone (`AppState`/`AppRouter`) — **BLOCKED on the
  signed build** (developer-machine action, T029 note): the codec + `AppRouter.resolve`
  nearest-valid fallback are implemented and unit-tested; only the OS-level restoration run on a
  signed install remains. **Triaged → backlog SP-7 (2026-07-09)** — tracked there with the other
  signed-build actions
- [X] T043 [US5] Register `.csv`/`.md` `UTType` drag-and-drop import in
  `Sources/FinanceWorkspaceApp/FinanceWorkspaceApp.swift` ✓ 2026-07-07 — window-wide
  `dropDestination` routes dropped CSVs into the import sheet pre-loaded (sync-gated);
  `CFBundleDocumentTypes` for csv+md registered on the app target (viewer role). `.md` drops are
  not importable documents in v1 (notes viewer is V2)
- [X] T044 [US5] Confirm the full macOS menu set incl. **Open Backup Folder** in
  `Sources/FinanceWorkspaceApp/UI/Shell/AppCommands.swift` ✓ 2026-07-07 — **verified already
  complete**: all 13 §17 commands present (New Record/Workspace, Open Workspace, Reindex,
  Validate, Import, New Paycheck Group, Export, Repair, Open Source File, Reveal in Finder,
  **Open Backup Folder**, Toggle Inspector), CommandMatrix-gated. No change needed
- [X] T045 [US5] Build the **require-iCloud** first-launch onboarding (enable-iCloud + retry; no local
  store; confirm success + "add your first account") in `Sources/FinanceWorkspaceApp/UI/Onboarding/`
  — delivered on branch `009-out-of-scope-followups`: `OnboardingView.swift` (3-step wizard,
  non-dismissable) + `AppState+Onboarding.swift` (provisioning, retry, safe-write apply). Satisfies
  spec.md acceptance scenarios 5 & 6 — `OnboardingCloudStatus.failure(reason:)` renders the
  enable-iCloud state with retry via Continue; `.success(path:)` confirms; Step 3 is "add your
  first account". "No local store" holds for RELEASE (`AppConfig.makeProvider()` never returns
  `LocalFolderProvider` outside `#if DEBUG` — DEBUG keeps the existing dev-local exception used
  throughout the app, not a deviation). Distribution note: this onboarding targets the
  **CloudDocs/direct-download** provider ladder (new this branch — `CloudDocsProvider.swift`),
  a second distribution path alongside the entitled-container target US3 (T029–T033) still
  assumes; the signed/notarized Xcode-target work and the conflict-resolution UI remain open.

**Checkpoint**: launch-quality accessibility + native behavior.

---

## Phase 8: User Story 6 — Trustworthy through tests (Priority: P4)

**Goal**: Fixture matrix, integration + XCUITest coverage, and bounded backups.

**Independent Test**: CI green across the fixture matrix + integration + view-model + XCUITest suites;
`backup-prune` reduces an over-limit set to policy.

- [X] T046 [P] [US6] `BackupPruneService` (keep last 10 per file OR < 30 days; prune only when both
  fail; skip in-flight-write backup by construction) + 5 tests in
  `Sources/FinanceWorkspaceKit/Persistence/Write/BackupPruneService.swift` and
  `Tests/FinanceWorkspaceKitTests/WriteEngineTests/BackupPruneTests.swift` (runtime-smoked via the CLI)
- [X] T047 [US6] Wire the prune trigger — **after each successful write** (`applyPendingWrite`) and
  **on launch** (`openWorkspace`) — in `Sources/FinanceWorkspaceApp/AppState+WriteFlows.swift` +
  `AppState.swift`; backed by the `backup-prune` CLI (`Sources/backup-prune/main.swift`)
- [X] T048 [P] [US6] Fixture matrix — one valid + one invalid fixture per managed file type, each
  invalid surfacing exactly its `RuleCatalog` issue, in `Tests/FinanceWorkspaceKitTests/Fixtures/`
  ✓ 2026-07-07 — `FixtureMatrixTests`: `FixtureWorkspace.full()` (all 23 types) validates clean;
  12 table-driven invalid cases assert exact rule ids (CROSS-001…010, DOMAIN-003/004/005/006) on
  exactly the offending file, + a file-tier malformed-values case. (The six predicate-less rules
  can't have invalid fixtures until backlog SP-4 wires them.)
- [X] T049 [P] [US6] Integration tests — full read flow; each write flow (intent → preview → backup →
  apply → re-index → re-validate); each auto-repair flow in `Tests/FinanceWorkspaceKitTests/`
  ✓ 2026-07-07 — `ReadWriteRepairIntegrationTests`: bootstrap→parse→validate→project;
  add/edit/delete round-trip with backup assertions; import month-split; multi-entry group
  write + whole-group delete; damage→plan→apply→re-validate-clean repair flow
- [X] T050 [P] [US6] `RepairApplyTests` — apply clears the issue after re-validate; manual-only offers
  no apply in `Tests/FinanceWorkspaceAppTests/RepairApplyTests.swift` ✓ 2026-07-07 (2 tests over
  `AppState.applyRepair` / `previewRepair`)
- [X] T051 [US6] XCUITest module-view smoke — every view loads, primary interaction works, **no
  permanently-disabled write button** in `Tests/FinanceWorkspaceUITests/ModuleSmokeUITests.swift`
  ✓ 2026-07-07 — sidebar walk + SC-001 enabled-write-button sweep; launches with the local
  provider + onboarding-complete defaults argument so CI runners land in the shell. Runs via
  `xcodebuild test -scheme FinanceWorkspace` (target + scheme test action added, T005)

**Checkpoint**: launch-gate coverage green; backups bounded.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T052 [P] Clear the `design-adherence` gate for all new/changed views (`TransactionGroupEditor`,
  `ReassignmentPickerView`, `ConflictResolutionView`, `OnboardingView`, typed `EntityEditForms`, the
  Budget export button); confirm `DesignSystem` tokens only ✓ 2026-07-07 — PASS: every view
  composes DS tokens + existing contracts (modal-form, status-chip, button styles); where the
  system lacked coverage, DESIGN.md was amended FIRST (v1.2 onboarding-wizard/step-indicator;
  v1.3 on-accent + contrast fixes). No hardcoded values; one accent; shadows on floating
  surfaces only
- [X] T053 [P] Update `docs/out-of-scope-followups.md` — close OOS-13…OOS-18 (and OOS-1/9) and
  re-triage anything still open ✓ 2026-07-07 — OOS-13/15/17/18 Resolved; OOS-14/16 Resolved with
  named backlog residue (UV-2 delete-in-edit, UV-6 transfers); OOS-1/9 stay partially-
  resolved/scheduled pending the developer-machine signed build (T029 note / T042)
- [X] T054 [P] Update `docs/test-plans.md` — mark the write-flow completion + launch flows testable;
  add the manual signed / two-device / performance / accessibility steps ✓ 2026-07-07 (Flow 10 +
  the formerly-blocked-flows status table; automated-suite pointers per flow)
- [~] T055 Run `specs/008-polish-launch/quickstart.md` end-to-end against a temp workspace —
  CLI portion ✓ 2026-07-07 (bootstrap 16 folders/46 files; 12-month fixture; validate clean
  0/0/0; backup-prune; live overview-dashboard). The interactive US1/US2 walkthrough + US3
  hardware steps + `swift test` remain manual / CI (CLT box cannot run them)
- [X] T056 Confirm CI green: `swift test` + `swiftlint --strict` + unsigned app-target build + XCUITest
  on the macOS runner ✓ 2026-07-09 (PR #23, runs 29038719225/29038719235 after two fix rounds —
  206 tests green; the first-ever execution of the 008 suites caught two real engine bugs:
  headerless new monthly files in `WriteService` and the never-firing savings-progress
  VAL-CROSS-008 key). **Caveat**: the XCUITest target builds but CI does not yet run
  `xcodebuild test` — adding that step is a small CI follow-up

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup — shared fixtures block the test-bearing stories.
- **User Stories (Phase 3–8)**: all depend on Foundational. **US1 is delivered** (only its tests
  remain). US2–US6 can then proceed in parallel or in priority order.
- **Polish (Phase 9)**: depends on the desired stories being complete.

### User-story dependencies

- **US1 (P1)**: delivered; tests independent.
- **US2 (P2)**: after Foundational. Reuses the merged write engine; independently testable.
- **US3 (P2)**: after Foundational. Signing config + conflict UI; independent of US2. Blocks
  full verification of **US5 T042** (`NSUserActivity` needs the signed app).
- **US4 (P3)**: after Foundational. Perf/reliability; independent.
- **US5 (P3)**: after Foundational. T042 is best verified once US3 signing lands.
- **US6 (P4)**: after Foundational. Test/QA harness + backup prune; independent.

### Parallel opportunities

- Setup: T001–T007 all `[P]`.
- Across stories: once Foundational completes, US2/US3/US4/US6 engine+UI work runs in parallel
  (different files); US1 tests first for regression safety.
- Within a story, the `[P]` test tasks run alongside each other.

---

## Implementation Strategy

### MVP-plus (US1 done → US2 next)

1. US1 is delivered — add T014/T015 to lock it, then move to US2 (finish the write flows) so the
   writable app is feature-complete.
2. US3 (sign + sync) is the distribution gate; land it before the launch-quality passes.
3. US4/US5 (perf, reliability, accessibility, native) harden the everyday experience.
4. US6 (tests + backup prune) underwrites everything and gates CI.
5. Polish (design gate, docs, quickstart, CI) last.

### Notes

- `[P]` = different files, no incomplete dependency.
- Every mutation still flows through `WriteService` — never reimplement backup/coordination/logging.
- The **only** schema change is the additive optional `transactions.description` column → no migration.
- Signing + two-device iCloud sync are manual on real hardware; CI stays unsigned.
- Commit after each task or logical group; stop at any checkpoint to validate a story independently.
