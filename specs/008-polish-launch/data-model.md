# Phase 1 Data Model: Polish & Launch Readiness (Phase 7)

This phase is overwhelmingly **behavior and configuration**, not new persistent data. There is exactly
**one file/schema change** (an additive optional column); everything else is either a reused Phase-6
value type or an in-memory config/behavior entity. No new file types, no migration.

## Schema change (the only file-model touch)

### `transactions` — + optional `description`

| Field | Type | Req? | Notes |
|---|---|---|---|
| … existing columns … | | | `transaction_id, account_id, date, amount, type, group_id, group_role, …` unchanged |
| **`description`** | string | **optional** | Imported memo/payee text. Absent-safe: files without it parse cleanly. **Additive optional → non-breaking → no `schema_version` bump, no migration** (constitution File & Schema Conventions). |

- **Consumers**: `ImportMapper` maps a source memo column into it; duplicate detection keys on
  **date + amount + description** within the target account (falls back to date + amount + account
  when description is absent).
- **Registered in**: `Sources/FinanceWorkspaceKit/Resources/Schemas/transactions.schema.json`
  + `CSVSchemaRegistry`.

## Reused write entities (Phase 6 — no change)

These ship already; Phase 7 builds UI/tests over them, not new types.

| Entity | Role in Phase 7 |
|---|---|
| `WritePlan` / `FileChange` / `WriteRowDiff` | every mutation (group write, reassign, form submit) still expands to one plan through `WriteService` |
| Multi-entry group (`group_id` + `group_role` rows) | `TransactionGroupEditor` authors N legs sharing one generated `group_id`, **all in one monthly file**; reconciles (transfers net 0; net = gross − Σ withholding) before apply |
| `ReferenceGroup` / `Reassignment` (`ReferenceScanner`) | the reassignment picker chooses a target per group; delete + reassignments stay one atomic plan |
| `RepairPlan` (`RepairService`) | US6 integration tests exercise plan → apply → re-validate |

## New in-memory config / behavior entities (no file persistence)

### PerformanceBudget

The ratified acceptance thresholds the measurement harness asserts against.

| Field | Value |
|---|---|
| coldLaunchToFirstProjection | ≤ 2s |
| fullReindex (12-month fixture) | ≤ 5s |
| uiResponsiveDuringReindex | no perceptible stall |
| repairApplyPlusRevalidate | ≤ 5s |
| baseline | current Apple Silicon |

### BackupRetentionPolicy

Governs `BackupPruneService`.

| Field | Value |
|---|---|
| keepPerFile | most recent **10** backups per source file |
| maxAge | prune backups older than **30 days** |
| rule | whichever is **more conservative** |
| trigger | after each successful write **and** on launch |
| safety | never remove a backup a current `WritePlan` references |

### ConflictResolution

The user-facing resolution over `NSFileVersion` (P-IV; no auto-merge).

| Field | Notes |
|---|---|
| conflictedFile | workspace-relative path in `conflict` sync state |
| versions | the `NSFileVersion` alternatives (current + others) |
| choice | keep-mine / keep-iCloud (explicit user pick) |
| resolve | apply choice, then `removeOtherVersions`; re-index |

### WriteAffordance (UI — delivered in US1)

Already implemented this session; recorded for completeness.

| Field | Notes |
|---|---|
| title / systemImage | Import / Add / Edit / New group / CTA |
| isEnabled | derives **only** from `AppState.writesEnabled` (runtime `WriteGate`) |
| disabledReason | `AppState.writeGateReason` — shown as tooltip when disabled |
| action | opens the existing add/edit/import flow |

### SignedAppArtifact (build config, not runtime data)

| Field | Value |
|---|---|
| signingIdentity | Developer ID Application |
| hardenedRuntime | enabled |
| entitlement | `iCloud.<bundle-id>` ubiquity container (already attached) |
| notarization | `notarytool` submit + staple (developer-machine release step) |
| ci | builds unsigned (`CODE_SIGNING_ALLOWED=NO`) |

## Validation & state rules

- **Multi-entry group**: legs share one `group_id`, one month, one file; group must reconcile before
  apply; whole-group is the unit for ledger edit/delete.
- **Reassignment**: every referencing collection must have a chosen target (or unlink/remove where the
  column permits) before apply; the reassignment target may not be the row being deleted.
- **`description`**: optional everywhere; its absence never errors and falls back the dedup key.
- **Backup prune**: idempotent; respects the in-flight-write exclusion.
- **Conflict**: unresolved conflicts block writes to that file (existing `WriteGate` sync-state gate).

## Entity relationship notes

No new relationships between file entities. The `description` column is a plain attribute on the
existing `transactions` rows. All cross-domain FKs (`account_id`, `category_id`, `account_group_id`,
`savings_goal_id`, sleeve/asset/liability links) are unchanged and remain enforced by
`ReferenceScanner` on delete.
