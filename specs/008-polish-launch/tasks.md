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

- [ ] T001 [P] Scaffold `Sources/FinanceWorkspaceApp/UI/Write/TransactionGroupEditor.swift` and
  `Sources/FinanceWorkspaceApp/UI/Write/ReassignmentPickerView.swift` (file headers only)
- [~] T002 [P] Scaffold `Sources/FinanceWorkspaceApp/UI/Onboarding/OnboardingView.swift` and
  `Sources/FinanceWorkspaceApp/UI/Shell/ConflictResolutionView.swift` (file headers only) —
  **`OnboardingView.swift` superseded**: built directly to full implementation on branch
  `009-out-of-scope-followups` rather than scaffolded first (see T045). `ConflictResolutionView.swift`
  is still unscaffolded (US3, T031).
- [X] T003 [P] Scaffold `Sources/FinanceWorkspaceKit/Persistence/Write/BackupPruneService.swift`
  (implemented fully with T046)
- [X] T004 [P] Add the `backup-prune` executable target (`Sources/backup-prune/main.swift`) and
  register it in `Package.swift`
- [ ] T005 [P] Scaffold the XCUITest target `Tests/FinanceWorkspaceUITests/` and add it to
  `App/project.yml` (macOS-runner only)
- [ ] T006 [P] Scaffold App-target write view-model test stubs in `Tests/FinanceWorkspaceAppTests/`:
  `WritePreviewViewModelTests.swift`, `ImportViewModelTests.swift`, `ReassignmentViewModelTests.swift`,
  `RepairApplyTests.swift`
- [ ] T007 [P] Scaffold the performance measurement harness
  `Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift`

---

## Phase 2: Foundational (shared prerequisites)

**⚠️ Blocks the test-bearing stories.** No engine changes — the Phase-6 write engine + safe-write path
are merged and remain the sole mutation path.

- [ ] T008 Confirm the merged `Persistence/Write/*` engine + `WriteService` safe-write path build and
  are unchanged; `swift build` green as the baseline for this phase
- [ ] T009 Extend the temp-workspace test helper (`Tests/FinanceWorkspaceKitTests/Fixtures/FixtureWorkspace.swift`
  + `Tests/FinanceWorkspaceAppTests/AppFixtures.swift`) to seed **all** managed file types — shared by
  the US6 fixture matrix, the integration tests, and the App write VM suites

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

- [ ] T014 [P] [US1] `WritePreviewViewModelTests` — apply → re-index, cancel no-op, `driftDetected` →
  re-preview in `Tests/FinanceWorkspaceAppTests/WritePreviewViewModelTests.swift`
- [ ] T015 [P] [US1] Smoke test asserting **no module view ships a permanently-disabled write button**
  (SC-001) in `Tests/FinanceWorkspaceAppTests/WriteAffordanceSmokeTests.swift`
- [ ] T016 [US1] Tick the delivered write-affordance-enablement + Edit-account-group tasks in
  `docs/product-roadmap.md` Phase 7

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
- [ ] T019 [US2] Wire **whole-group** edit/delete from the ledger in
  `Sources/FinanceWorkspaceApp/UI/Shared/LedgerTableView.swift` and
  `Sources/FinanceWorkspaceApp/UI/Accounts/AccountGroupDetailView.swift`

### Reassignment picker (D2 · OOS-17)

- [ ] T020 [P] [US2] `ReassignmentViewModelTests` — apply blocked until every group chosen,
  self-deleted target rejected in `Tests/FinanceWorkspaceAppTests/ReassignmentViewModelTests.swift`
- [ ] T021 [US2] Build `ReassignmentPickerView` (one picker per collection; "leave unlinked" only when
  nullable; list replace/remove) in `Sources/FinanceWorkspaceApp/UI/Write/ReassignmentPickerView.swift`
- [ ] T022 [US2] Replace `requestDelete`'s first-available-target default with the picker selection in
  `Sources/FinanceWorkspaceApp/AppState+WriteFlows.swift`

### Budget Markdown export (D3 · OOS-18)

- [X] T023 [US2] Add the "Export summary (Markdown)" action → `ExportService.budgetSummaryMarkdown` via
  a save panel in `Sources/FinanceWorkspaceApp/UI/Budget/BudgetOverviewView.swift`

### Typed entity forms (D4 · OOS-13)

- [ ] T024 [US2] Add the `(file, column)` → control map (grouped parent pickers, sign-aware amount
  fields, enum pickers sourced from `CSVSchemaRegistry`) in
  `Sources/FinanceWorkspaceApp/UI/Write/EntityEditForms.swift`

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
- [ ] T028 [P] [US2] `ImportViewModelTests` — required-unmapped blocks advance, duplicates
  default-excluded, target account required in `Tests/FinanceWorkspaceAppTests/ImportViewModelTests.swift`

**Checkpoint**: the writable app is feature-complete; US1 still works.

---

## Phase 5: User Story 3 — Signed, installable, iCloud-syncing build (Priority: P2)

**Goal**: Developer ID signed + notarized build; manual pick-a-version conflict resolution.

**Independent Test**: Install a signed build on two Macs; edit on A → appears on B; force a conflict →
"conflict detected" → pick a version → resolves with no data loss.

- [ ] T029 [US3] Configure Developer ID Application signing + hardened runtime + notarization settings
  in `App/project.yml`
- [ ] T030 [US3] Document the `xcodegen generate` → build → `notarytool submit` → `stapler` release
  step in `docs/_notes/running-and-testing.md`
- [ ] T031 [US3] Build the conflict-resolution surface (list `NSFileVersion` alternatives; keep-mine /
  keep-iCloud; `removeOtherVersions`; re-index) in
  `Sources/FinanceWorkspaceApp/UI/Shell/ConflictResolutionView.swift` + `AppState`
- [ ] T032 [US3] Surface the per-file "conflict detected" entry point from the header sync chip →
  conflict surface in `Sources/FinanceWorkspaceApp/UI/Shell/` (header)
- [ ] T033 [US3] Record the manual two-device sync + conflict verification protocol in
  `docs/test-plans.md`

**Checkpoint**: a real signed build syncs across devices and resolves conflicts safely.

---

## Phase 6: User Story 4 — Fast & resilient (Priority: P3)

**Goal**: Meet ≤2s/≤5s; stay responsive; never crash or mix stale/fresh on sparse data.

**Independent Test**: Harness proves ≤2s cold-launch / ≤5s re-index on the 12-month fixture; external
edits keep the UI interactive; sparse fixtures render designed empty states.

- [ ] T034 [P] [US4] Performance harness asserts cold-launch → first-projection ≤ 2s and full re-index
  ≤ 5s on the 12-month fixture in `Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift`
- [ ] T035 [US4] Hash-keyed per-domain projection cache (recompute only changed domains, keyed by
  `ManifestStore` hashes) in `Sources/FinanceWorkspaceApp/ProjectionStore.swift`
- [ ] T036 [US4] Debounce `FileWatcherService` bursts into one re-index in
  `Sources/FinanceWorkspaceKit/Platform/FileWatcherService.swift`
- [ ] T037 [US4] Lazy-load module views + audit parse/validate off the main actor in
  `Sources/FinanceWorkspaceApp/` (routing) / `ProjectionStore`
- [ ] T038 [P] [US4] Reliability tests — last-known-valid projection served during re-index (no
  stale/fresh mix); sparse/empty/partial-column fixtures never crash in
  `Tests/FinanceWorkspaceKitTests/Unit/EdgeCaseTests.swift`

**Checkpoint**: performance budget met; resilient under real data.

---

## Phase 7: User Story 5 — Accessible, native & polished (Priority: P3)

**Goal**: Keyboard + VoiceOver + WCAG AA; restoration; drag-drop; full menu; require-iCloud onboarding.

**Independent Test**: Navigate every view by keyboard; VoiceOver + contrast pass in light/dark;
relaunch restores; drag a CSV imports; iCloud-off launch shows enable-iCloud + retry.

- [ ] T039 [P] [US5] VoiceOver `.accessibilityLabel` audit across interactive elements in
  `Sources/FinanceWorkspaceApp/UI/`
- [ ] T040 [P] [US5] WCAG AA contrast audit of `DesignSystem` tokens (light + dark); fix any failure
  via `design-token-sync` in `Sources/FinanceWorkspaceApp/DesignSystem/`
- [ ] T041 [US5] Keyboard-navigation audit (sidebar → main → inspector; arrows/Return/Escape) across
  `Sources/FinanceWorkspaceApp/UI/Shell/` + tables
- [ ] T042 [US5] Verify `NSUserActivity` restoration end-to-end in the **signed** app; restore to the
  nearest valid context when the prior entity is gone (`AppState`/`AppRouter`)
- [ ] T043 [US5] Register `.csv`/`.md` `UTType` drag-and-drop import in
  `Sources/FinanceWorkspaceApp/FinanceWorkspaceApp.swift`
- [ ] T044 [US5] Confirm the full macOS menu set incl. **Open Backup Folder** in
  `Sources/FinanceWorkspaceApp/UI/Shell/AppCommands.swift`
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
- [ ] T048 [P] [US6] Fixture matrix — one valid + one invalid fixture per managed file type, each
  invalid surfacing exactly its `RuleCatalog` issue, in `Tests/FinanceWorkspaceKitTests/Fixtures/`
- [ ] T049 [P] [US6] Integration tests — full read flow; each write flow (intent → preview → backup →
  apply → re-index → re-validate); each auto-repair flow in `Tests/FinanceWorkspaceKitTests/`
- [ ] T050 [P] [US6] `RepairApplyTests` — apply clears the issue after re-validate; manual-only offers
  no apply in `Tests/FinanceWorkspaceAppTests/RepairApplyTests.swift`
- [ ] T051 [US6] XCUITest module-view smoke — every view loads, primary interaction works, **no
  permanently-disabled write button** in `Tests/FinanceWorkspaceUITests/ModuleSmokeUITests.swift`

**Checkpoint**: launch-gate coverage green; backups bounded.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [ ] T052 [P] Clear the `design-adherence` gate for all new/changed views (`TransactionGroupEditor`,
  `ReassignmentPickerView`, `ConflictResolutionView`, `OnboardingView`, typed `EntityEditForms`, the
  Budget export button); confirm `DesignSystem` tokens only
- [ ] T053 [P] Update `docs/out-of-scope-followups.md` — close OOS-13…OOS-18 (and OOS-1/9) and
  re-triage anything still open
- [ ] T054 [P] Update `docs/test-plans.md` — mark the write-flow completion + launch flows testable;
  add the manual signed / two-device / performance / accessibility steps
- [ ] T055 Run `specs/008-polish-launch/quickstart.md` end-to-end against a temp workspace
- [ ] T056 Confirm CI green: `swift test` + `swiftlint --strict` + unsigned app-target build + XCUITest
  on the macOS runner

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
