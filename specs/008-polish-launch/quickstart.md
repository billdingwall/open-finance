# Quickstart: Polish & Launch Readiness (Phase 7)

Exercise each story. Use a **throwaway** workspace, never real data:

```bash
swift run bootstrap-workspace --workspace /tmp/pl/Finance
swift run fixture-generate    --workspace /tmp/pl --months 12
swift build            # expect: Build complete!
swift test             # write VM + multi-entry + dedup + backup-prune + fixture-matrix (macOS CI)
```

## US1 — visible write actions (delivered)

Launch `swift run FinanceWorkspaceApp` (DEBUG → local-folder provider at `~/Finance-Dev`). From the
**visible toolbar/sidebar/empty states only** (no ⌘N): add an account group (sidebar "New group"),
add an account, import a CSV, edit an account, **edit an account group** (new action), add a budget
category, add a goal. Each opens the correct form/flow → preview + backup → applies. Confirm every
write button is enabled (or disabled only with a sync-reason tooltip); no "Phase 6" placeholder.

## US2 — finish the write flows

- **Multi-entry**: author a paycheck group (gross → withholding → net, same month) → watch it
  reconcile → apply → all legs land in one `YYYY-MM.csv`. Edit/delete it from the ledger → whole group
  moves/removes together.
- **Reassignment**: delete a category used by transactions → pick a target per collection → apply →
  category gone, every referencing row repointed, one atomic backup.
- **Budget export**: Budget → "Export summary (Markdown)" → a `.md` with period header + category
  breakdown lands **outside** the workspace.
- **Typed forms**: edit a goal/account → parent references use pickers, amounts are sign-aware, enums
  use pickers.
- **description column**: import a bank CSV with a memo column → memo retained on each row; a
  same-date/amount/description row is flagged duplicate. Old transaction files without `description`
  still parse.

## US3 — signed + iCloud (manual, real hardware)

```bash
xcodegen generate --spec App/project.yml     # then build/sign/notarize in Xcode
```
Install the signed, notarized build on two Macs (one Apple ID). Edit on A → see it on B with per-file
sync state. Force a conflict → the app surfaces "conflict detected" → pick a version → resolves (no
auto-merge, no data loss).

## US4 — performance & reliability

- Run the measurement harness on the 12-month fixture: cold-launch → first projection **≤ 2s**; full
  re-index **≤ 5s**; UI stays interactive during re-index (edit files externally while using it).
- Point at sparse/empty/partial fixtures → designed empty/partial states, no crash, no stale/fresh mix.

## US5 — accessibility & native

- Navigate every view by **keyboard alone**; run a **VoiceOver** pass and a **WCAG AA** contrast check
  in light + dark. Resize to the 900px minimum.
- Relaunch → restores the prior module + selection (verify in the **signed** app).
- Drag a `.csv` onto the app → import offered. Open the menu → all commands incl. **Open Backup
  Folder**. Launch with iCloud off → "enable iCloud" + retry (no local store).

## US6 — tests & QA

```bash
swift test    # fixture matrix (valid+invalid/type), read/write/repair integration, view-model suites
# XCUITest module-view smoke runs on the macOS runner
swift run backup-prune --workspace /tmp/pl/Finance   # reduces an over-limit backup set to policy
```
Confirm: backups never exceed **last-10 + 30-day**; pruning runs after each write + on launch and
never removes an in-flight-write's backup.

## Gate

`swift build` green · `swift test` + `swiftlint --strict` + unsigned app-target build green in CI ·
every new/changed view cleared `design-adherence` · **no schema change except the additive optional
`transactions.description` column** (no migration).
