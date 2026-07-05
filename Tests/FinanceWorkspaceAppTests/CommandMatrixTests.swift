import Testing
@testable import FinanceWorkspaceApp

// T020 — the §17 menu enable/disable matrix (contracts/app-shell.md): Phase-6 flows are always
// disabled; selection-context commands gate on a source selection; workspace commands gate on
// an open workspace.

@Suite struct CommandMatrixTests {

    // Export + Repair-apply land with US5/US6 — still disabled after US1.
    @Test func exportAndRepairRemainDisabled() {
        let everything = CommandMatrix(hasWorkspace: true, hasSourceSelection: true,
                                       activeModuleHasAddTarget: true)
        #expect(everything.isEnabled(.exportCurrentView) == false)
        #expect(everything.isEnabled(.repairSelectedIssue) == false)
    }

    // ⌘N New Record is context-sensitive: needs a workspace AND an active module with an add target.
    @Test func newRecordIsContextSensitive() {
        #expect(CommandMatrix(hasWorkspace: true, hasSourceSelection: false,
                              activeModuleHasAddTarget: true).isEnabled(.newRecord))
        #expect(CommandMatrix(hasWorkspace: true, hasSourceSelection: false,
                              activeModuleHasAddTarget: false).isEnabled(.newRecord) == false)
        #expect(CommandMatrix(hasWorkspace: false, hasSourceSelection: false,
                              activeModuleHasAddTarget: true).isEnabled(.newRecord) == false)
    }

    @Test func selectionContextCommandsGateOnSourceSelection() {
        let without = CommandMatrix(hasWorkspace: true, hasSourceSelection: false)
        let with = CommandMatrix(hasWorkspace: true, hasSourceSelection: true)
        #expect(without.isEnabled(.openSourceFile) == false)
        #expect(without.isEnabled(.revealInFinder) == false)
        #expect(with.isEnabled(.openSourceFile))
        #expect(with.isEnabled(.revealInFinder))
    }

    @Test func workspaceCommandsGateOnOpenWorkspace() {
        let closed = CommandMatrix(hasWorkspace: false, hasSourceSelection: false)
        let open = CommandMatrix(hasWorkspace: true, hasSourceSelection: false)
        for command in [AppCommand.reindexWorkspace, .validateWorkspace, .openBackupFolder] {
            #expect(closed.isEnabled(command) == false)
            #expect(open.isEnabled(command))
        }
    }

    @Test func alwaysAvailableCommands() {
        let closed = CommandMatrix(hasWorkspace: false, hasSourceSelection: false)
        #expect(closed.isEnabled(.newWorkspace))
        #expect(closed.isEnabled(.openWorkspace))
        #expect(closed.isEnabled(.toggleInspector))
    }
}
