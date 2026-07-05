# Quickstart — Write Flows, Repair & Export (Phase 6)

Exercise every write flow against a **throwaway** fixture workspace. Writes are real — never point
these at a workspace you care about. Backups land in `.finance-meta/backups/`; every write is logged
to `.finance-meta/logs/repair-log.csv`.

## Build

```bash
swift build            # CLT-only box: builds Kit + App + CLIs (write engine lives in the Kit)
swift test             # full Xcode / macOS CI: runs the write-engine + view-model suites
swiftlint --strict     # Linux CI
```

## Provision a temp workspace

```bash
swift run bootstrap-workspace --workspace /tmp/Finance-W6/Finance
swift run fixture-generate    --workspace /tmp/Finance-W6 --months 12
swift run validate-workspace  --workspace /tmp/Finance-W6/Finance   # baseline: should be clean
```

## Run the app against it

```bash
swift run FinanceWorkspaceApp   # DEBUG → local-folder provider; point it at /tmp/Finance-W6/Finance
```

## Walk the six flows (maps to the user stories)

1. **US1 — structured edit**: Savings & Investments → a goal → Edit (right-panel bottom) → change the
   target amount → the write preview shows target file + before/after row + backup location → Apply.
   Confirm the goal updates and a `goals.csv.<ts>.bak` exists. Repeat Add and Delete.
2. **US2 — import**: File → Import (⌘-import) → pick a 2-month bank CSV → confirm the auto-detected
   mapping + sign convention + **target account** → preview groups rows by month, flags duplicates →
   Apply. Confirm rows land in the two `Accounts/transactions/YYYY-MM.csv` files with backups.
3. **US3 — multi-entry**: add a paycheck group (gross income → tax withholding → net deposit) →
   reconciliation indicator turns valid (`net = gross − Σ withholding`) → Apply writes all legs
   atomically. Delete the group → all legs removed.
4. **US4 — delete-with-reassign**: Budget → delete a category used by transactions → preview lists the
   referencing transactions with a reassignment picker → choose a target → Apply. Confirm the category
   is gone and every referencing transaction now points to the chosen category — both in one plan.
5. **US5 — repair**: introduce a repairable issue (e.g. lower-case a header in a CSV) →
   `validate-workspace` or the Overview issues table shows it → Preview Repair (diff) → Apply Repair
   (⇧⌘R) → issue clears after re-validation; a repair-log entry is written.
6. **US6 — export**: open a transactions table → Export Current View (⌘E) → save CSV → confirm it
   contains the visible rows + `source_file`/`source_row` columns. Budget → export the monthly summary
   → confirm the Markdown period header + category breakdown. No workspace file changes.

## Sync-gate check (SC-008)

With a file in a syncing/stale/conflicted state, every Apply is disabled with the `WriteGate` reason
and nothing is written. `WriteService.apply` re-checks the gate even if the UI is bypassed.

## CI gates

- `swift test`: `WriteServiceTests` (backup-before-write, atomic-failure-leaves-original, gate-block,
  drift), `CSVRowSerializerTests` (round-trip + byte-stability + sign), `ReferenceScannerTests`,
  `ImportMapperTests`, `ExportServiceTests`, `MultiEntryWriteTests`, updated `CommandMatrixTests`.
- SwiftLint `--strict`.
- Unsigned app-target build (Phase-5 XcodeGen step) still green.
