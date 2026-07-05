# Contract — Write Engine (`FinanceWorkspaceKit/Persistence/Write/`)

The Kit-level, CI-testable core. Composes the Phase-1 primitives (`BackupService`,
`FileCoordinatorService`, `WriteGate`) and MUST NOT reimplement them (FR-002).

## WriteService

```
public struct WriteService {
    init(workspaceURL: URL,
         backups: BackupService,
         coordinator: FileCoordinatorService = .init(),
         manifest: ManifestStore)

    /// Build a previewable plan for an intent. Writes nothing.
    func preview(_ intent: WriteIntent, ...) throws -> WritePlan

    /// Apply a plan atomically: WriteGate check → drift check → backup every touched file →
    /// coordinated atomic write of each FileChange → append repair-log entries.
    /// Throws (leaving all files untouched) on gate-blocked, drift, or backup failure.
    @discardableResult
    func apply(_ plan: WritePlan,
               workspaceState: SyncState,
               fileStates: [String: FileSyncState]) throws -> WriteResult
}
```

**Guarantees**
- **G1**: `apply` calls `BackupService.backup` for every touched file *before* any write; if any
  backup throws, no target file is modified (FR-003, SC-002).
- **G2**: Each `FileChange` is written via `FileCoordinatorService.coordinatedWrite` with atomic
  temp-then-rename; a failure mid-plan leaves already-written files restorable from backup and
  un-started files untouched (FR-004, SC-003).
- **G3**: `apply` returns early with a thrown reason if `WriteGate.evaluate` denies the workspace or
  any target file's state (FR-005, SC-008) — checked before G1.
- **G4**: `apply` compares each `FileChange.expectedHash` to the current file hash; on mismatch it
  throws `driftDetected(path)` so the UI re-previews (D8) — no overwrite.
- **G5**: Every applied plan appends one line per action to `.finance-meta/logs/repair-log.csv`
  (`timestamp,target_file,action_kind,backup_path,result`) (FR-007, constitution P-IV).

## CSVRowSerializer

```
public enum CSVRowSerializer {
    /// Typed entity → canonical CSV row string (schema column order).
    static func row<E: WritableEntity>(_ entity: E, schema: CSVSchema) -> String

    /// Apply RowDiffs to existing file text, editing only changed rows in place.
    /// Preserves the leading `# schema_version: N` comment and all untouched rows byte-for-byte.
    static func applyDiffs(_ diffs: [RowDiff], to fileText: String, schema: CSVSchema) throws -> String
}
```

**Guarantees**
- **S1**: `parse(serialize(x)) == x` for every entity type (round-trip identity).
- **S2**: For an unchanged file, `applyDiffs([], text) == text` byte-for-byte (no reformatting).
- **S3**: Amount columns keep the negative=debit sign convention; no silent flips.
- **S4**: Column order matches `CSVSchemaRegistry`; the `# schema_version` row is preserved.

## ReferenceScanner

```
public struct ReferenceScanner {
    init(context: WorkspaceContext)   // parsed workspace

    /// All rows referencing `id` in `collection`, grouped by referencing collection+column.
    func referencesTo(id: String, in collection: String) -> [ReferenceGroup]

    /// Valid reassignment targets for a group (same collection, excluding the deletion set).
    func reassignTargets(for group: ReferenceGroup, excluding deleted: Set<String>) -> [String]
}
```

**Guarantees**
- **R1**: Every FK edge in the schema-derived map (research D3) is scanned — including
  `goals.source_account_id`, `account-rules.category_id`, the six `transactions` FKs, the polymorphic
  `tax-adjustments.linked_id`, and the list-valued `budgets.account_ids`/`account_group_ids`; a delete
  surfaces *all* referencing rows (FR-019) — no silent orphan (SC-005).
- **R2**: `nullable` is true iff the schema marks the FK column optional (enables "leave unlinked",
  FR-020); list-valued columns (`isList`) always allow removal.
- **R3**: `reassignTargets` never returns an id in `deleted` (FR-022).
- **R4**: For a list-valued FK, reassignment replaces the deleted id within the cell's list (or
  removes it), never rewrites unrelated members; the serializer edits only that cell.

## Contract tests (Swift Testing, macOS CI)

- WriteService: backup-before-write (G1), atomic-failure-leaves-original (G2), gate-block (G3),
  drift-throws (G4), log-appended (G5) — all against a temp workspace.
- CSVRowSerializer: round-trip identity (S1), empty-diff byte-stability (S2), sign preserved (S3),
  schema order + comment row (S4).
- ReferenceScanner: full edge coverage (R1), nullable detection (R2), self-deleted target rejected
  (R3).
