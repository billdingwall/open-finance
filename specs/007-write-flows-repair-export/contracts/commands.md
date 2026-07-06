# Contract — Commands & Write Gating (`UI/Shell/AppCommands.swift`)

Phase 6 activates the write/export commands stubbed disabled in Phase 5 and adds the add-record
action. `CommandMatrix` stays the pure, unit-tested enable/disable seam.

## CommandMatrix additions

```
enum AppCommand {
    // existing: newWorkspace, openWorkspace, reindexWorkspace, validateWorkspace,
    //           openSourceFile, revealInFinder, openBackupFolder, toggleInspector
    case exportCurrentView       // NEW — was disabled(true)
    case repairSelectedIssue     // NEW — was disabled(true)
    case newRecord               // NEW — ⌘N add-record
}

struct CommandMatrix {
    let hasWorkspace: Bool
    let hasSourceSelection: Bool
    let hasExportableView: Bool          // NEW
    let hasRepairableSelection: Bool     // NEW
    let activeModuleHasAddTarget: Bool   // NEW
    func isEnabled(_ c: AppCommand) -> Bool
}
```

| Command | Menu | Shortcut | Enabled when |
|---|---|---|---|
| Export Current View | File | ⌘E | `hasWorkspace && hasExportableView` |
| Repair Selected Issue | Workspace | ⇧⌘R | `hasWorkspace && hasRepairableSelection` |
| New Record | File | ⌘N | `hasWorkspace && activeModuleHasAddTarget` (FR-030a) |

Unchanged commands keep their Phase-5 rules. ⌘N being context-sensitive means it is disabled on
modules with no primary add target (e.g. Overview).

## Write-affordance gating (runtime, per action)

Independent of the menu matrix, every individual write affordance (form Apply, import Apply, repair
Apply, delete Apply, year-close) is gated at press time by:

```
WriteGate.evaluate(workspaceState: SyncState, fileState: FileSyncState) -> Decision
```

- Blocked ⇒ affordance disabled, `Decision.reason` shown inline (FR-005, SC-008).
- This is the same gate `WriteService.apply` re-checks server-side (defense in depth, G3).

## Tests (macOS CI — `CommandMatrixTests`)
- Export enabled only with a workspace + exportable view; disabled otherwise.
- Repair enabled only with a repairable selection.
- New Record enabled per active-module add target; disabled on Overview.
- Existing command rules unchanged (regression).
