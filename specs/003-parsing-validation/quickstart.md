# Quickstart: Parsing, Validation & Infrastructure (Phase 2)

Validates the Phase 2 read pipeline end-to-end against a local-folder workspace — no iCloud required.

## Prerequisites

- Phase 1 merged (workspace provisioning, file index, manifest, backup, sync/write-gate, domain models).
- Swift 6 toolchain. `swift test` needs full Xcode (runs in `ci-macos.yml`); `swift build` + executables run on CLT-only.

## 1. Generate fixtures

```bash
swift run fixture-generate --workspace ~/Finance-Dev --months 12        # valid baseline
# (Phase 2 adds:) a defect-seeded variant and a synthetic pre-R6 variant for tests
```

## 2. Parse + validate

```bash
swift run validate-workspace --workspace ~/Finance-Dev/Finance
```
Expect: every managed file type parses into typed records; on the valid fixture, **zero errors and zero false-positive warnings**. A row with a bad date/decimal/enum appears as a *partial record* and surfaces as a single file-level issue (not a dropped row, not a crash).

## 3. Inspect the issue stream

```bash
swift run validate-workspace --workspace ~/Finance-Dev/Finance --json --report /tmp/validation.json
```
Expect: one unified `ValidationResult` containing both rule firings and lifted parse warnings, grouped by severity. On the defect-seeded fixture, each defined rule fires exactly once with the correct `VAL-<TIER>-<NNN>` id, severity, and repair class.

## 4. Preview + apply a repair

```bash
swift run repair-workspace --workspace ~/Finance-Dev/Finance --dry-run   # diff only, no writes
swift run repair-workspace --workspace ~/Finance-Dev/Finance --apply     # backup + atomic + log
swift run repair-workspace --workspace ~/Finance-Dev/Finance --apply     # no-op (idempotent)
```
Expect: the auto-repairable defect (e.g. a missing optional column / missing seed file / missing folder / header-casing) is fixed; a timestamped backup exists; `.finance-meta/logs/repair-log.csv` has a new row; the second `--apply` changes nothing. Manual-only issues are untouched.

## 5. Settings round-trip

In a test (or REPL): read `WorkspaceSettings` from `Taxes/settings.csv`; delete the file and confirm typed defaults are produced; change `taxYear`, write it back (backed-up, atomic), and re-read identically.

## 6. R6 migration (legacy workspaces only)

```bash
swift run migrate-r6 --workspace ~/Legacy-Finance/Finance --dry-run      # change plan, no writes
swift run migrate-r6 --workspace ~/Legacy-Finance/Finance --apply        # backed-up, atomic
swift run migrate-r6 --workspace ~/Legacy-Finance/Finance --apply        # no-op on R6-native
```
Expect: legacy files/columns renamed, `Investments/transactions.csv` folded into the unified ledger as `type = trade` rows, new R6 files seeded, `schema_version` bumped, manifest updated — losslessly; re-run is a no-op.

## Success criteria coverage

| Step | Success Criteria |
|---|---|
| 2 | SC-001, SC-002, SC-009 |
| 3 | SC-003 |
| 4 | SC-004, SC-005 |
| 5 | SC-006 |
| 2–4 (CLIs) | SC-007 |
| 6 | SC-008 |
