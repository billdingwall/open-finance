# Contract — Developer CLI Scripts (Phase 1)

Swift scripts under `Scripts/`. They operate on a workspace path so the file-based logic is testable
outside the app. Canonical detail: `docs/architecture/data-pipelines.md §2`.

## `bootstrap-workspace`

```
swift Scripts/bootstrap-workspace.swift --workspace <path>
```
- Creates the standard folder tree (see `workspace-layout.md`).
- Writes seed CSV/Markdown templates **from `.finance-meta/schemas/` JSON schemas**, each with a
  leading `# schema_version: 1` comment row.
- Seeds six starter accounts, default categories, the standard tax-adjustment row.
- Writes `Workspace.md`. (The manifest is created by the app's `ManifestStore` on first index, not by
  bootstrap, since it is device-local.)
- **Idempotent**: existing files preserved; exit non-zero only on unrecoverable error.

## `fixture-generate`

```
swift Scripts/fixture-generate.swift --workspace ~/Finance-Dev [--months 12]
```
- Populates a realistic dataset (≥12 months of transactions, accounts, goals, assets) into a
  local-folder workspace for development, first-run testing, and CI.
- Output MUST pass `FileIndexService` classification + scan cleanly.

## Acceptance

- After `bootstrap-workspace`, the app launching against that path validates the workspace as
  complete and indexes it with zero errors (SC-001).
- After `fixture-generate`, a cold scan + hash completes within a few seconds on Apple Silicon
  (SC-002) and a manifest delete + relaunch reproduces an identical index (SC-004).
- Both scripts run on the local-folder provider with no iCloud configured (SC-007).
