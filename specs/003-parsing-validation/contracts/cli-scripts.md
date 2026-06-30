# Contract — Developer CLI Scripts (Phase 2)

New SwiftPM executable targets, run via `swift run <exe>` (matching the Phase 1 convention for `bootstrap-workspace` / `fixture-generate` / `index-check`). They operate on a workspace path so the file-based logic is testable outside the app. Canonical detail: `docs/architecture/data-pipelines.md §2`.

## `validate-workspace`

```
swift run validate-workspace --workspace <path>/Finance [--json] [--report <out.json>]
```
- Scans + parses the workspace, runs the **full** `ValidationEngine` pass.
- Prints an issue summary **grouped by severity** (errors, warnings, info) with rule ID, file, row, and message per issue.
- `--json` / `--report`: emit a machine-readable `ValidationResult` (for CI / tooling).
- Exit code: non-zero when any **error**-severity issue is present; zero when only warnings/info.

## `repair-workspace`

```
swift run repair-workspace --workspace <path>/Finance (--dry-run | --apply)
```
- `--dry-run` (default): produces the `RepairPlan` and prints a before/after **diff** for every auto-repairable issue; writes **nothing**.
- `--apply`: backs up each target (Phase 1 `BackupService`), applies atomically, appends to `.finance-meta/logs/repair-log.csv`. Sync-gated; **idempotent** (re-run ⇒ no-op, no new backup).
- Never touches manual-only issues.

## `migrate-r6`

```
swift run migrate-r6 --workspace <path>/Finance (--dry-run | --apply)
```
- Detects a pre-R6 workspace (legacy file names or older `schema_version`); a no-op on R6-native workspaces.
- `--dry-run`: prints the full change plan (renames, ledger fold, seeds, version bump, manifest update); writes nothing.
- `--apply`: performs each step atomically, **backed up**: rename `entities.csv`→`account-groups.csv` (`entity_id`→`account_group_id`), `holdings.csv`→`assets.csv` (`holding_id`→`asset_id`), `deductions.csv`→`tax-adjustments.csv` (`deduction_id`→`tax_adjustment_id`); fold `Investments/transactions.csv` rows into `Accounts/transactions/YYYY-MM.csv` as `type = trade` rows by date; seed new R6 files; bump `schema_version`; update the manifest.
- In-app, migration is **detect-and-prompt** (clarify Q5) — the CLI is the explicit invocation path; neither auto-applies.

## Acceptance

- `validate-workspace` on a valid fixture ⇒ zero errors; on a defect-seeded fixture ⇒ each rule reported once with correct classification (SC-003, SC-007).
- `repair-workspace --dry-run` shows a correct diff and writes nothing; `--apply` fixes the defect, leaves a backup + repair-log entry, and a second `--apply` is a no-op (SC-004, SC-007).
- `migrate-r6` on a synthetic pre-R6 fixture migrates losslessly and is a no-op on re-run (SC-008).
- All three run on the local-folder provider with no iCloud configured.
