import SwiftUI
import AppKit
import FinanceWorkspaceKit

// T019/T020 — the §17 macOS menu command set (contracts/app-shell.md, research D5).
// `CommandMatrix` is the pure, unit-testable enable/disable logic; Phase-6 flows (Export,
// Repair apply) are present but disabled (FR-007).

enum AppCommand: CaseIterable {
    case newWorkspace, openWorkspace, reindexWorkspace, validateWorkspace, exportCurrentView
    case repairSelectedIssue, openSourceFile, revealInFinder, openBackupFolder, toggleInspector
    case newRecord
}

/// Pure enable/disable matrix — the single source for both the menu and its tests.
struct CommandMatrix {
    var hasWorkspace: Bool
    var hasSourceSelection: Bool
    var activeModuleHasAddTarget: Bool = false
    var hasRepairableSelection: Bool = false

    func isEnabled(_ command: AppCommand) -> Bool {
        switch command {
        case .newWorkspace, .openWorkspace, .toggleInspector:
            return true
        case .reindexWorkspace, .validateWorkspace, .openBackupFolder, .exportCurrentView:
            return hasWorkspace
        case .newRecord:
            return hasWorkspace && activeModuleHasAddTarget      // context-sensitive (FR-030a)
        case .repairSelectedIssue:
            return hasWorkspace && hasRepairableSelection        // US5
        case .openSourceFile, .revealInFinder:
            return hasSourceSelection
        }
    }
}

extension AppState {
    /// The source reference of the current detail-pane selection, if any.
    var selectedSourceRef: SourceRef? {
        switch detailPane.surface {
        case .inspector(let ref): return ref
        case .issueDetail(let issue): return issue.sourceRef
        default: return nil
        }
    }

    var commandMatrix: CommandMatrix {
        CommandMatrix(hasWorkspace: workspaceURL != nil,
                      hasSourceSelection: selectedSourceRef != nil,
                      activeModuleHasAddTarget: activeModuleHasAddTarget,
                      hasRepairableSelection: hasRepairableSelection)
    }
}

/// The app menu (File / Workspace / View additions).
struct AppCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Record") { state.presentAddForActiveModule() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!state.commandMatrix.isEnabled(.newRecord))
            Button("New Workspace") { Task { await state.openWorkspace() } }
                .keyboardShortcut("n", modifiers: [.shift, .command])
                .disabled(!state.commandMatrix.isEnabled(.newWorkspace))
            Button("Open Workspace") { Task { await state.openWorkspace() } }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(!state.commandMatrix.isEnabled(.openWorkspace))
            Divider()
            Button("Reindex Workspace") { Task { await state.reindex() } }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!state.commandMatrix.isEnabled(.reindexWorkspace))
            Button("Validate Workspace") {
                Task {
                    await state.reindex()
                    state.router.navigate(to: .overview)
                }
            }
            .keyboardShortcut("v", modifiers: [.shift, .command])
            .disabled(!state.commandMatrix.isEnabled(.validateWorkspace))
            Divider()
            Button("Import Transactions…") { state.showingImport = true }
                .keyboardShortcut("i", modifiers: [.shift, .command])
                .disabled(state.workspaceURL == nil)
            Button("Export Current View…") { exportCurrentView() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!state.commandMatrix.isEnabled(.exportCurrentView))
        }

        CommandMenu("Workspace") {
            Button("Repair Selected Issue…") { Task { await state.applyRepair() } }
                .keyboardShortcut("r", modifiers: [.shift, .command])
                .disabled(!state.commandMatrix.isEnabled(.repairSelectedIssue))
            Divider()
            Button("Open Source File") { openSelectedSource(inEditor: true) }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!state.commandMatrix.isEnabled(.openSourceFile))
            Button("Reveal in Finder") { openSelectedSource(inEditor: false) }
                .keyboardShortcut("r", modifiers: [.option, .command])
                .disabled(!state.commandMatrix.isEnabled(.revealInFinder))
            Divider()
            Button("Open Backup Folder") { openBackups() }
                .disabled(!state.commandMatrix.isEnabled(.openBackupFolder))
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector") { state.detailPane.isPresented.toggle() }
                .keyboardShortcut("i", modifiers: [.option, .command])
        }
    }

    private func openSelectedSource(inEditor: Bool) {
        guard let ref = state.selectedSourceRef, let root = state.workspaceURL else { return }
        let url = root.appendingPathComponent(ref.filePath)
        if inEditor {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func openBackups() {
        guard let root = state.workspaceURL else { return }
        let backups = root.appendingPathComponent(".finance-meta/backups", isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([backups])
    }

    /// Export the active module's primary view as CSV (with provenance) to a chosen destination.
    private func exportCurrentView() {
        guard let export = state.exportCurrentViewCSV() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "export-\(export.suggestedName)"
        panel.allowedContentTypes = [.commaSeparatedText]
        if panel.runModal() == .OK, let url = panel.url {
            state.writeExport(export.text, to: url)
        }
    }
}
