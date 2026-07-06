# Phase 0 Research: Polish & Launch Readiness (Phase 7)

Plan-level decisions. The three clarify sessions already fixed the product-level unknowns (perf
targets, distribution, retention, scope, iCloud-unavailable, conflict UX, group model, prune trigger);
this file records the *implementation* approach. No open `NEEDS CLARIFICATION`.

Format per decision: **Decision · Rationale · Alternatives rejected**.

---

## D1 — Multi-entry transaction editor (US2, FR-005; OOS-16)

**Decision**: Build `TransactionGroupEditor` as a SwiftUI form that authors N leg rows sharing a
generated `group_id`, with a **live reconciliation indicator** (transfers net to zero; `net = gross −
Σ withholding`) and Apply disabled until balanced. All legs are constrained to **one month → one
monthly file** and written via the existing `WriteService` group plan (one `FileChange`, N `RowDiff`s).
From the ledger (`LedgerTableView`, `AccountGroupDetailView`), edit/delete acts on the **whole group**
(resolve the group_id, load all legs into the editor / delete them atomically).

**Rationale**: the reconciliation + atomic group-write/delete engine (`MultiEntry`,
`MultiEntryWriteTests`) already shipped in Phase 6; this is UI over it. Same-month/one-file (clarify
Q8) keeps atomicity in a single `FileChange` — no cross-file transaction needed. Whole-group ledger
ops (clarify Q9) preserve the reconciliation invariant by construction.

**Alternatives rejected**: cross-month legs (needs multi-file atomic write — rejected Q8);
single-leg ledger edit (can break reconciliation — rejected Q9); re-authoring the engine (violates
NFR-002 reuse).

## D2 — Reassignment picker (US2, FR-006; OOS-17)

**Decision**: Build `ReassignmentPickerView` — one picker per referencing collection surfaced by
`ReferenceScanner.referencesTo`, offering `reassignTargets` (excluding the deleted id); "leave
unlinked" only when the column is nullable; replace-in-list / remove-from-list for list-valued FKs.
Apply is blocked until every group has a choice. Replace `AppState.requestDelete`'s current
first-available-target default with the user's selection; the delete + reassignments still expand into
**one atomic plan** (already implemented).

**Rationale**: `ReferenceScanner` (nullable/list detection, target validity) and the atomic
delete-plus-reassign plan shipped in Phase 6; only the interactive picker was deferred. Never orphans
a row (SC-002).

**Alternatives rejected**: block-delete-when-referenced (worse UX, and the atomic plan already
exists); auto-pick without confirmation (the current stopgap — replaced by user choice).

## D3 — Budget Markdown-summary export (US2, FR-007; OOS-18)

**Decision**: Add an "Export summary (Markdown)" action to `BudgetOverviewView` that calls the
existing `ExportService.budgetSummaryMarkdown` and writes via `fileExporter`/save panel to a
destination the service already guards as **outside the workspace**.

**Rationale**: `budgetSummaryMarkdown` exists and is unit-tested; only the in-view button is unwired.

**Alternatives rejected**: a new Markdown generator (duplicate); exporting into the workspace
(rejected by `ExportService.write`'s workspace-internal guard).

## D4 — Typed entity edit controls (US2, FR-008; OOS-13)

**Decision**: Layer type-aware controls onto the existing schema/header-driven `EntityEditForm`: a
control map keyed by (file, column) yields grouped `Picker`s for parent references
(account-group/category parents, target account), sign-aware amount fields (money in/out per the
sign convention), and enum `Picker`s for enumerated columns (status, account_type, frequency,
adjustment_type…). Columns without a typed mapping keep the labelled text field. The submit path is
unchanged (`finishEditForm` → `WritePlan` → preview).

**Rationale**: keeps the one safe-write submit path; the typed controls are presentation only. Enum
value sets come from `CSVSchemaRegistry` (already the source of truth), so no hardcoded lists.

**Alternatives rejected**: a bespoke form per entity (12× duplication); free-text everything (the
current stopgap — poor validation/UX).

## D5 — Optional `transactions.description` column + dedup (US2, FR-009; OOS-15)

**Decision**: Add `description` as an **optional** column to `transactions.schema.json` and the
`CSVSchemaRegistry` (absent-safe: existing files without it parse cleanly, no `schema_version` bump,
no migration — adding an optional column is constitution-sanctioned as non-breaking). `ImportMapper`
maps a source memo/payee column into it and changes the duplicate key to **date + amount + description
within the target account** (falling back to date + amount + account when description is absent).

**Rationale**: retains imported bank memos and matches the clarified dedup key; the constitution
explicitly exempts optional-column additions from migration.

**Alternatives rejected**: a required column (breaking → migration); a side file for memos (splits
the ledger, violates P-I unified ledger).

## D6 — App-target write test suites (US1/US2, FR-024; deferred T010/T021/T032/T036)

**Decision**: Add the deferred view-model/integration suites: WritePreview (apply → re-index, cancel
no-op, drift → re-preview), Import (required-unmapped blocks advance, duplicates default excluded,
target account required), Reassignment (blocked until every group chosen, self-deleted target
rejected), RepairApply (apply clears the issue after re-validate; manual-only offers no apply), plus a
smoke test asserting **no module ships a permanently-disabled write button** (SC-001).

**Rationale**: closes the Phase-6 test residue and locks the US1 fix against regression.

**Alternatives rejected**: relying on manual testing (regresses silently).

## D7 — Code signing + notarization (US3, FR-010; OOS-1)

**Decision**: Configure Developer ID Application signing + hardened runtime + notarization on the
XcodeGen `App/project.yml` target (the iCloud ubiquity-container entitlement is already attached).
CI keeps building **unsigned** (`CODE_SIGNING_ALLOWED=NO`); signing + `notarytool` submission +
stapling are a documented developer-machine release step. No Mac App Store / TestFlight this phase
(clarify Q2).

**Rationale**: direct distribution matches the "notarize" intent and the single-container entitlement
already in place; keeps CI unchanged.

**Alternatives rejected**: App Store sandbox (adds entitlement/review constraints — deferred);
signing in CI (needs secrets on a hosted runner — out of scope).

## D8 — iCloud sync + conflict resolution (US3, FR-011/012)

**Decision**: Reuse `ICloudContainerService` (`NSMetadataQuery` per-file sync state already wired).
For conflicts, surface a **"conflict detected"** state and a resolution view that lists the
`NSFileVersion` alternatives and lets the user **pick which to keep** (keep-mine / keep-iCloud), then
resolves via `NSFileVersion.removeOtherVersions` — no auto-merge (P-IV, clarify Q6). Two-device
verification is a **manual** protocol on a signed build (can't run in CI).

**Rationale**: matches the locked constitution mandate (explicit user choice) and the clarified UX.

**Alternatives rejected**: auto-merge / latest-wins (prohibited by P-IV); keep-both copies (rejected
Q6).

## D9 — Performance (US4, FR-013/014/015)

**Decision**: (a) A measurement harness records cold-launch-to-first-projection and full re-index of
the 12-month fixture, asserting **≤2s / ≤5s** on Apple Silicon. (b) Per-domain **projection caching
keyed by source-file hashes** (from `ManifestStore`) so re-index recomputes only changed domains.
(c) Keep parse/validate/`ProjectionStore.build` off the main actor (Phase-5 already async — audit it).
(d) **Debounce** `FileWatcherService` bursts (e.g. bulk import) into one re-index. (e) Lazy-load
module views so cold launch doesn't block on all engines.

**Rationale**: hash-keyed caching is the highest-leverage win and reuses the manifest already
computed; debounce prevents import thrashing.

**Alternatives rejected**: full recompute every change (fails ≤5s at scale); time-based cache
invalidation (hashes are exact and already available).

## D10 — Reliability (US4/US5, FR-016/017)

**Decision**: Persist the **last-known-valid projection** per module (already partially: `AppState`
keeps the prior snapshot visible during re-index and surfaces `reindexError`) and serve it during
re-index, guaranteeing no view mixes stale + fresh figures (one atomic snapshot swap — already the
pattern). Audit every engine for sparse/empty/partial-column inputs → designed empty/partial states,
never a crash (extends the Phase-3/4 partial-average handling).

**Rationale**: FR-016/017 are constitution P-II bullets; the atomic-swap pattern already exists —
this hardens and tests it.

**Alternatives rejected**: blocking the UI during re-index (fails FR-014); per-row partial UI (mixes
stale/fresh — rejected by FR-017).

## D11 — Accessibility & native behavior (US5, FR-018–022)

**Decision**: VoiceOver labels on every interactive element (extend the existing
`.accessibilityLabel` usage); a WCAG AA contrast audit across all `DesignSystem` tokens in light +
dark (feeds `design-token-sync` if any token fails); a keyboard-nav audit (sidebar→main→inspector,
arrows/Return/Escape); verify `NSUserActivity` restoration **end-to-end in the signed app** (codec
already unit-tested — OOS-9); register `.csv`/`.md` `UTType` drag-and-drop import; confirm the full
menu set incl. **Open Backup Folder**; and a **require-iCloud** first-launch onboarding flow
(enable-iCloud + retry state; no local store — clarify Q5).

**Rationale**: these are P-III obligations; most infrastructure exists (command matrix, activity
codec, tokens) — this phase completes and audits it.

**Alternatives rejected**: local-folder onboarding fallback (rejected Q5 — keeps provider dev-only).

## D12 — Backup retention/prune + QA harness (US6, FR-023/024/025)

**Decision**: `BackupPruneService` in `Persistence/Write/` enforces **keep last 10 per source file +
prune > 30 days** (whichever more conservative), run **after each successful write and on launch**,
skipping any backup a current `WritePlan` references (race-safety). A `backup-prune` CLI mirrors it.
Build the **one-valid/one-invalid fixture per managed file type** matrix; integration tests for the
full read flow, each write flow, and each auto-repair flow; and an **XCUITest** target smoke-testing
every module view (no permanently-disabled write button, primary interactions work).

**Rationale**: bounds backup growth per the clarified policy/trigger; the fixture matrix + XCUITest
are the launch-gate coverage (research D8 of Phase 5 deferred XCUITest to here).

**Alternatives rejected**: manual-only prune (backups grow unbounded — rejected Q10); count-only or
age-only retention (rejected in clarify — the combined bound is safest).

---

## Resolved unknowns summary

| Area | Resolution | Source |
|---|---|---|
| Multi-entry file/month scope | one month → one file; whole-group ledger ops | Clarify Q8/Q9 → D1 |
| Reassignment UX | per-collection picker over existing atomic plan | D2 |
| Budget Markdown export | wire existing `budgetSummaryMarkdown` | D3 |
| Typed forms | schema-registry-driven control map | D4 |
| `description` column | additive optional, no migration; dedup date+amount+description | D5 |
| Signing | Developer ID + notarize, CI stays unsigned | Clarify Q2 → D7 |
| Conflict resolution | manual pick-a-version over `NSFileVersion` | Clarify Q6 → D8 |
| Performance | hash-keyed projection cache; ≤2s/≤5s harness | Clarify Q1 → D9 |
| Backup retention/prune | last-10 + 30d, after write + on launch | Clarify Q3/Q10 → D12 |
| Onboarding | require iCloud + retry (no local store) | Clarify Q5 → D11 |
