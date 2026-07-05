import Testing
@testable import FinanceWorkspaceApp

// T020 — the §17 menu enable/disable matrix (contracts/app-shell.md): Phase-6 flows are always
// disabled; selection-context commands gate on a source selection; workspace commands gate on
// an open workspace.

@Suite struct CommandMatrixTests {

    @Test func phase6CommandsAreAlwaysDisabled() {
        let everything = CommandMatrix(hasWorkspace: true, hasSourceSelection: true)
        #expect(everything.isEnabled(.exportCurrentView) == false)
        #expect(everything.isEnabled(.repairSelectedIssue) == false)
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
