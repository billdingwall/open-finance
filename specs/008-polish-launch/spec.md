# Feature Specification: Polish & Launch Readiness (Phase 7)

**Feature Branch**: `008-polish-launch`  
**Created**: 2026-07-06  
**Status**: Draft  
**Input**: User description: "Phase 7 — Polish & Launch Readiness. Harden the merged v1 app (Phases 1–6) for launch, adding no new product surface beyond finishing Phase-6 write flows. Scope is defined by Phase 7 of docs/product-roadmap.md."

## Overview

Phases 1–6 delivered a writable, fully navigable macOS finance workspace. This phase makes it
**launch-ready**: it first closes the gap where the app's advertised write actions are not actually
reachable from the visible UI, finishes the write flows deliberately deferred during Phase 6, then
hardens the app across distribution (signing + real iCloud sync), performance, reliability,
accessibility, native behavior, and test coverage. **No new product surface** is introduced beyond
completing Phase-6 write flows; the one data-model change is a single additive, optional column.

## Clarifications

### Session 2026-07-06

- Q: Performance acceptance thresholds for Phase 7 (SC-003 / FR-013)? → A: Cold-launch-to-first-projection ≤ 2s and full re-index of the 12-month fixture ≤ 5s on current Apple Silicon, UI interactive throughout.
- Q: Primary distribution + signing target (FR-010 / US3)? → A: Developer ID signing + notarization for direct distribution (no Mac App Store / TestFlight in this phase).
- Q: Backup retention policy the prune routine enforces (FR-025)? → A: Keep the most recent 10 backups per source file and prune any older than 30 days (whichever is more conservative).
- Q: Is Phase 7 correctly scoped as one spec, or split? → A: Keep as one spec — all six user stories stay in `008-polish-launch`, sequenced by priority.
- Q: At first launch, if iCloud is unavailable, what should the shipped app do (FR-022)? → A: Require iCloud — block workspace creation with clear guidance to enable iCloud and a retry; **no** user-facing local-folder store (keeps the DEBUG local-folder provider dev-only and the "local folder → V2" out-of-scope line intact). *(Reversed an initial "offer local fallback" answer, 2026-07-06.)*
- Q: How is a sync conflict resolved in the UI (FR-012)? → A: Surface the conflicting file versions and let the user pick which to keep (manual resolution, no auto-merge — matches the locked `NSFileVersion` decision).
- Q: How much of a multi-entry transaction group can be edited after creation (FR-005)? → A: Full structural edit — add / remove / modify legs, with live re-reconciliation required before apply.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every visible write action actually works (Priority: P1)

A user opens the app against their workspace and sees Import / Add / Edit buttons on each module's
title bar, a "New group" button in the sidebar, and "add your first…" calls-to-action on empty
screens. Today most of these render permanently greyed out (left over from the read-only phase), so
the only way to write is via the keyboard shortcut or the inspector. The user expects every visible
write button to do something.

**Why this priority**: The app already contains the full write engine and forms, but the primary,
discoverable entry points are dead. This makes the shipped writability effectively invisible and is
the single most damaging first-run impression. It is the smallest change that turns the app from
"looks read-only" into "obviously writable."

**Independent Test**: Launch against a throwaway workspace; from the visible toolbar/sidebar/empty
states alone (no keyboard shortcuts), add an account group, add an account, import a CSV, edit an
account, add a budget category, add a goal, and edit an account group — each opens the correct form
or flow and completes a safe write with a preview and backup.

**Acceptance Scenarios**:

1. **Given** a writable, in-sync workspace, **When** the user clicks the title-bar **Add** on the
   Accounts screen, **Then** the add form opens, and on confirm the new row is written through the
   safe-write path (preview → backup → atomic apply → re-index) and appears in the list.
2. **Given** the account-group screen, **When** the user looks at the title-bar actions, **Then** an
   **Edit** action is present (it is entirely absent today) and opens the account-group edit form.
3. **Given** the sidebar, **When** the user clicks **New group**, **Then** the account-group add
   form opens (it is disabled today).
4. **Given** an empty module screen, **When** the user clicks its empty-state call-to-action, **Then**
   the matching add flow opens.
5. **Given** a workspace whose sync state blocks writing, **When** the user views any write action,
   **Then** it is disabled with a tooltip explaining the sync reason — the **only** legitimate
   disabled state (no "available in a future phase" placeholders remain anywhere).

---

### User Story 2 - Finish the deferred write flows (Priority: P2)

A user wants to author a paycheck as one grouped transaction (gross → withholdings → net), choose
where referencing rows go when deleting a shared entity, export a budget month as a Markdown summary,
edit entities with type-appropriate controls, and have imported bank memos retained.

**Why this priority**: These are the consciously deferred pieces of Phase 6 (the engine shipped and
is tested; the UI/one column did not). Completing them makes the writable app feature-complete before
launch hardening, but the app is already usable without them, so they rank below the P1 dead-button
fix.

**Independent Test**: Author a balanced paycheck group and see it written atomically; delete a
category used by transactions and pick the reassignment target per collection; export a budget month
to Markdown; edit a goal via typed controls; import a CSV and confirm the memo is retained and used
for duplicate detection.

**Acceptance Scenarios**:

1. **Given** the multi-entry editor, **When** the user authors a paycheck whose legs do not
   reconcile, **Then** apply is blocked with a live reconciliation indicator; when the legs balance,
   applying writes all legs atomically to the correct monthly file.
2. **Given** a ledger group, **When** the user edits or deletes it, **Then** every leg sharing the
   group id moves or is removed together.
3. **Given** a delete of a referenced entity, **When** the preview appears, **Then** the user can
   choose a reassignment target per referencing collection (replace, or leave unlinked/remove only
   where allowed); on apply the delete and reassignments are one atomic plan and no row is orphaned.
4. **Given** the Budget month view, **When** the user chooses "Export summary (Markdown)", **Then** a
   Markdown file with the period header and category breakdown is written to a chosen destination
   outside the workspace.
5. **Given** an entity edit form, **When** editing fields, **Then** parent references use grouped
   pickers, amounts are sign-aware, and enumerated fields use pickers (not free text).
6. **Given** a bank CSV with a memo/description column, **When** imported, **Then** the memo is
   retained on each row and duplicate detection keys on date + amount + description within the target
   account.

---

### User Story 3 - Signed, installable app with working iCloud sync (Priority: P2)

A user installs the app on two of their own Macs signed into the same Apple ID, edits the workspace
on one, and sees the change sync to the other; if a conflict arises, they are guided to resolve it.

**Why this priority**: Real cross-device iCloud sync is the core promise of the product and is a hard
distribution gate (an unsigned build cannot exercise a real iCloud container). It ranks with US2 as a
launch necessity but below the P1 first-run fix.

**Independent Test**: Produce a signed, notarized build; install on two devices; make an edit on
device A and observe it appear on device B; introduce a conflicting edit and confirm the app surfaces
a "conflict" state with resolution guidance.

**Acceptance Scenarios**:

1. **Given** a signed, notarized build, **When** it launches on a real device, **Then** it resolves
   the iCloud workspace container (no entitlement/signing errors) and reads/writes it.
2. **Given** two devices on the same account, **When** an edit is saved on device A, **Then** device
   B reflects it after sync, with per-file sync state shown throughout.
3. **Given** conflicting edits to the same file on two devices, **When** they sync, **Then** the app
   surfaces a "conflict detected" state and lets the user pick which version to keep, rather than
   silently losing data.

---

### User Story 4 - Fast and resilient under real data (Priority: P3)

A user with a realistic 12-month, multi-account, multi-entity workspace expects the app to launch
quickly, stay responsive while re-indexing after external edits, and never crash or show blank/zero
projections when data is sparse or partially filled.

**Why this priority**: Performance and resilience protect the everyday experience but do not block a
first demo on modest data; they matter most as real datasets grow.

**Independent Test**: Against a realistic fixture, measure cold-launch-to-first-projection (≤2s) and
full re-index time (≤5s); edit files externally during use and confirm the UI stays
responsive and shows no mixed stale/fresh data; run against sparse/empty/partially-filled fixtures and
confirm designed empty states rather than crashes or zeros.

**Acceptance Scenarios**:

1. **Given** a realistic 12-month workspace, **When** the app cold-launches, **Then** the first
   projections appear within 2s and a full re-index completes within 5s.
2. **Given** a re-index triggered by external file changes, **When** it runs, **Then** the UI remains
   interactive, the last-known-valid projection is shown until the new one is ready, and no view mixes
   stale and fresh figures.
3. **Given** missing months, empty files, or partially-filled optional columns, **When** any module
   renders, **Then** it shows a sensible empty/partial state with no crash.
4. **Given** a burst of rapid file changes (e.g. a bulk import), **When** the watcher fires, **Then**
   events are debounced into a single re-index rather than thrashing.

---

### User Story 5 - Accessible, native, and polished (Priority: P3)

A user relying on VoiceOver, keyboard-only navigation, dark mode, or a small window can use every
part of the app; menu commands, window restoration, and drag-and-drop behave like a native macOS app;
first launch guides a new user to create a workspace and add their first account.

**Why this priority**: Accessibility and native polish are launch-quality expectations but not
blockers for internal validation of function.

**Independent Test**: Navigate every view by keyboard alone; run a VoiceOver pass and a WCAG AA
contrast check across light and dark; resize to the minimum window; relaunch and confirm the prior
view/selection restores; drag a CSV onto the app to import; complete the first-launch onboarding from
an empty container.

**Acceptance Scenarios**:

1. **Given** keyboard-only input, **When** the user tabs across sidebar → main → inspector and uses
   arrows/Return/Escape within tables and the pane, **Then** every interactive element is reachable
   and operable with a visible focus order.
2. **Given** VoiceOver enabled, **When** navigating any view, **Then** interactive elements have
   descriptive labels; **and** all text/status colors meet WCAG AA contrast in light and dark mode.
3. **Given** the app is relaunched, **When** it restores, **Then** it returns to the same module and
   selection as before quit.
4. **Given** a `.csv`/`.md` file dragged onto the app, **When** dropped, **Then** the appropriate
   import/behavior is offered.
5. **Given** a brand-new empty iCloud container, **When** the user first launches, **Then** an
   onboarding flow creates the workspace, confirms success, and prompts adding a first account.
6. **Given** iCloud is unavailable at first launch, **When** onboarding runs, **Then** it blocks
   workspace creation with a clear "enable iCloud" state and a retry (no local-folder store), and
   proceeds once iCloud is available.
7. **Given** the full macOS menu, **When** the user opens it, **Then** every documented command
   (including Open Backup Folder) is present and enabled when applicable.

---

### User Story 6 - Trustworthy through automated tests (Priority: P4)

A maintainer needs confidence that read, write, and repair flows keep working. The test suite covers a
valid and invalid fixture per file type, integration tests for read/write/repair flows, automated UI
smoke tests of the module views, and a backup-pruning safeguard so backups do not grow unbounded.

**Why this priority**: This underwrites the other stories and prevents regressions but delivers no
direct user-facing capability, so it ranks last.

**Independent Test**: CI runs the full validation fixture matrix, the read/write/repair integration
tests, and the UI smoke tests green; the backup-prune routine reduces an over-limit backup set to the
retention policy.

**Acceptance Scenarios**:

1. **Given** the fixture suite, **When** CI runs, **Then** there is one valid and one invalid fixture
   per managed file type, and each invalid one surfaces exactly its intended issue.
2. **Given** the integration suite, **When** CI runs, **Then** the full read flow, each write flow
   (intent → preview → backup → apply → re-index → re-validate), and each auto-repair flow pass.
3. **Given** module views, **When** the automated UI smoke tests run, **Then** each view loads and its
   primary interactions work without a permanently-disabled write button.
4. **Given** a source file with more than the retained number of backups, **When** pruning runs,
   **Then** older backups beyond the policy are removed and the newest are kept.

---

### Edge Cases

- **Sync-blocked writes**: when the workspace is not in a writable sync state, every write affordance
  is disabled with a reason — this must be visually distinct from the (now-removed) permanent
  read-only placeholders so users can tell "not yet synced" from "not supported."
- **Delete of an entity referenced across multiple collections**: the reassignment picker must cover
  every referencing collection; applying with any collection unresolved is blocked unless that
  collection permits unlink/remove.
- **Multi-entry group spanning a month boundary or failing reconciliation**: apply is blocked until
  the group balances; a partially-written group must never be left on disk.
- **Adding the optional description column to files that predate it**: reading older transaction files
  without the column must not error; the column is optional and absent-safe.
- **Backup pruning racing an in-progress write**: pruning must never remove a backup that a current
  write plan depends on.
- **Window restoration to a view whose entity no longer exists** (deleted since last launch): restore
  to the nearest valid context rather than an error.
- **First launch when iCloud is unavailable**: onboarding must present a clear "enable iCloud" state
  with a retry (not a crash or a silent dead-end), and proceed to workspace creation once iCloud
  becomes available.

## Requirements *(mandatory)*

### Functional Requirements

#### Write-affordance enablement (US1)

- **FR-001**: The app MUST make every visible top-level write action operable — module title-bar
  Import / Add / Edit, the sidebar "New group", and empty-state calls-to-action — replacing the
  read-only placeholder actions with handlers that open the existing add/edit/import/preview flows.
- **FR-002**: The account-group screen MUST provide an **Edit** action for the group itself (today
  absent), opening the account-group edit form through the safe-write path.
- **FR-003**: The **only** disabled state for a write action MUST be a runtime sync/writability block,
  shown with a tooltip stating the reason; no action may be permanently disabled or labeled as
  deferred to a later phase.
- **FR-004**: Every entity MUST have at least one discoverable, working write entry point from the
  visible UI, consistent with the keyboard command and inspector edit/delete.

#### Complete deferred write flows (US2)

- **FR-005**: Users MUST be able to author, edit, and delete a multi-entry transaction group (e.g.
  paycheck, transfer, split) as one unit. Editing MUST allow **full structural change** — adding,
  removing, or modifying individual legs — with a live reconciliation indicator that re-checks after
  any change; apply MUST be blocked until the group reconciles, and all legs MUST be written or
  removed atomically.
- **FR-006**: When deleting a referenced entity, users MUST be able to choose a reassignment target
  per referencing collection (replace; or leave-unlinked/remove only where the reference permits); the
  delete plus all reassignments MUST apply as one atomic plan that never orphans a row.
- **FR-007**: Users MUST be able to export the current Budget month as a Markdown summary (period
  header + category breakdown) to a destination outside the workspace.
- **FR-008**: Entity edit forms MUST use type-appropriate controls: grouped pickers for parent
  references, sign-aware amount entry, and pickers for enumerated fields.
- **FR-009**: The transaction record MUST support an optional description/memo field so imported bank
  memos are retained; duplicate detection on import MUST use date + amount + description within the
  target account. The field MUST be additive and optional (absent-safe for existing files).

#### Distribution & sync (US3)

- **FR-010**: The app MUST ship as a **Developer ID-signed, notarized** build (direct distribution;
  Mac App Store / TestFlight is out of scope for this phase) carrying the iCloud container
  entitlement, launching without entitlement/signing errors on a real device.
- **FR-011**: The app MUST synchronize workspace changes across devices on the same account and show
  per-file sync state throughout.
- **FR-012**: The app MUST detect sync conflicts and surface a "conflict detected" state that
  presents the conflicting file versions and lets the user **choose which version to keep** (manual
  resolution, no auto-merge), never silently discarding a user's edits.

#### Performance (US4)

- **FR-013**: The app MUST meet these performance acceptance criteria on current Apple Silicon:
  cold-launch-to-first-projection ≤ 2s; full re-index of the realistic 12-month fixture ≤ 5s; the UI
  stays interactive (no perceptible stalls) during re-index; repair-apply-plus-re-validate completes
  within the same ≤ 5s re-index bound.
- **FR-014**: The app MUST keep the UI responsive during background parsing/validation/re-index (work
  off the main thread) and MUST debounce rapid file-change events into a single re-index.
- **FR-015**: Each domain projection MUST be cached and re-computed only for domains whose source
  files changed.

#### Reliability (US4/US5)

- **FR-016**: Every module MUST handle sparse, empty, or partially-filled data with a designed
  empty/partial state and never crash.
- **FR-017**: During re-index the app MUST serve the last-known-valid projection and MUST never
  display a mix of stale and fresh figures within a view.

#### Accessibility & native behavior (US5)

- **FR-018**: All interactive elements MUST be reachable and operable by keyboard alone, with a
  coherent focus order across sidebar → main → inspector and arrow/Return/Escape behavior in tables
  and the pane.
- **FR-019**: All interactive elements MUST expose descriptive accessibility labels, and all
  text/status/chart colors MUST meet WCAG AA contrast in both light and dark mode.
- **FR-020**: The app MUST restore the prior module and selection on relaunch, degrading gracefully to
  the nearest valid context when the prior selection no longer exists.
- **FR-021**: The app MUST expose the full documented macOS menu command set (including Open Backup
  Folder), each enabled only when applicable, and MUST accept `.csv`/`.md` drag-and-drop.
- **FR-022**: First launch MUST guide a new user through workspace creation; when iCloud is
  unavailable it MUST **block workspace creation with clear guidance to enable iCloud and a retry**
  (no user-facing local-folder store in v1). On success it MUST confirm and prompt adding a first
  account.

#### Test & QA hardening (US6)

- **FR-023**: The workspace MUST include one valid and one invalid fixture per managed file type, each
  invalid fixture surfacing exactly its intended validation issue.
- **FR-024**: Automated tests MUST cover the full read flow, each write flow end-to-end (intent →
  preview → backup → apply → re-index → re-validate), each auto-repair flow, and a UI smoke pass of
  every module view.
- **FR-025**: The app MUST enforce a backup retention policy — keep the most recent 10 backups per
  source file and prune any older than 30 days (whichever is more conservative) — and provide a
  pruning routine that applies it without removing a backup an in-progress write needs.

### Non-Functional Constraints

- **NFR-001**: No schema change is permitted **except** the additive optional transaction
  description column (FR-009); the change MUST be backward-compatible with existing workspaces.
- **NFR-002**: All writes MUST continue to flow through the existing safe-write path (timestamped
  backup + atomic coordinated apply + sync gate + repair log); the safe-write primitives MUST NOT be
  reimplemented.
- **NFR-003**: This phase MUST NOT add product surface beyond completing Phase-6 write flows; all
  V1-out-of-scope items remain out of scope.

### Key Entities

- **Write action (UI affordance)**: a user-visible control that initiates a write; carries an
  enabled/disabled state that MUST derive only from runtime writability, plus the flow it launches.
- **Multi-entry transaction group**: a set of transaction rows sharing a group id and role that must
  reconcile (transfers net to zero; net = gross − withholdings) and move atomically.
- **Reference reassignment**: a mapping, per referencing collection, from a to-be-deleted entity to a
  replacement target (or unlink/remove where permitted), applied atomically with the delete.
- **Transaction (amended)**: gains an optional description/memo attribute used for retention and
  duplicate detection; otherwise unchanged.
- **Backup set / retention policy**: the collection of timestamped backups per source file and the
  rule governing how many are kept.
- **Signed app artifact**: the notarized, entitled application build used for real-device iCloud
  testing and distribution.
- **Performance budget**: the set of measurable thresholds the app is validated against.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of visible write actions across all modules are operable (or disabled only with a
  sync reason); zero permanently-disabled or "future phase" placeholders remain.
- **SC-002**: A user can complete each core write task — add account/group, import CSV, edit an
  entity, author a paycheck group, delete-with-reassignment, export a budget summary — end-to-end from
  the visible UI, each producing a backup and leaving no orphaned rows.
- **SC-003**: On a realistic 12-month workspace, first projections appear within 2s of cold launch
  and a full re-index completes within 5s (current Apple Silicon), with the UI remaining interactive
  throughout.
- **SC-004**: The app runs from a signed, notarized build and successfully syncs an edit between two
  devices, surfacing conflicts rather than losing data.
- **SC-005**: Every view is fully operable by keyboard alone and passes a VoiceOver label pass and a
  WCAG AA contrast check in light and dark mode.
- **SC-006**: No module crashes or shows blank/zero projections on sparse, empty, or partially-filled
  fixtures.
- **SC-007**: The automated suite is green in CI, covering a valid+invalid fixture per file type, each
  read/write/repair flow, and a UI smoke pass; backups never exceed the retention policy.
- **SC-008**: Relaunch restores the prior module and selection in the common cases, and no workspace
  file is modified by any read-only session.

## Assumptions

- **Performance, backup retention, and distribution channel** were ratified in the 2026-07-06
  clarification session (see Clarifications) — ≤2s/≤5s targets, last-10 + 30-day retention, and
  Developer ID + notarization respectively — and are now encoded in FR-013/FR-025/FR-010 and SC-003.
- The **iCloud container identifier** is unchanged from the locked `iCloud.<bundle-id>` decision.
- **iCloud testing** requires a signed build on real hardware (two Macs on one Apple ID); it cannot be
  fully validated in CI, which continues to build the app unsigned.
- **Reuse over rebuild**: the multi-entry, reassignment, export-Markdown, and validation/repair
  **engines** already exist and are unit-tested from Phase 6; this phase wires UI and adds tests, not
  new engines. The single data change is the optional description column.
- **Onboarding scope**: first-launch onboarding covers workspace creation and iCloud-availability
  states (require iCloud + retry when unavailable — no local store in v1); it does not introduce new
  product modules.
- The realistic dataset for performance/reliability testing is 12 months of transactions across ~3
  investment accounts and ~2 business entities with a full deduction/adjustment set.
