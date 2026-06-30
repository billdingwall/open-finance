import Foundation
import FinanceWorkspaceKit

// T037 — migrate-r6 CLI. Detects a pre-R6 workspace; --dry-run prints the change plan (no writes);
// --apply performs the renames + ledger fold, each backed up. No-op on an R6-native workspace.
// In-app the same migration is detect-and-prompt (clarify Q5); this CLI is the explicit path.

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: migrate-r6 --workspace <path> [--dry-run | --apply]\n".utf8))
    exit(2)
}

var workspacePath: String?
var apply = false
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--apply": apply = true
    case "--dry-run": apply = false
    case "-h", "--help": usage()
    default: break
    }
}
guard let workspacePath else { usage() }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)
let service = MigrationService()

guard service.isPreR6(workspaceURL: root) else {
    print("migrate-r6: workspace is already R6-native — nothing to do ✓")
    exit(0)
}

do {
    if apply {
        let plan = try service.apply(workspaceURL: root)
        print("migrate-r6: applied \(plan.steps.count) step(s)")
        for step in plan.steps { print("  • \(step)") }
    } else {
        let plan = service.plan(workspaceURL: root)
        print("migrate-r6 (dry-run): \(plan.steps.count) step(s) — no files written")
        for step in plan.steps { print("  • \(step)") }
        print("Re-run with --apply to perform the migration.")
    }
} catch {
    FileHandle.standardError.write(Data("migrate-r6 failed: \(error)\n".utf8))
    exit(1)
}
