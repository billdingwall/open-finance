import Foundation
import FinanceWorkspaceKit

// T032 — repair-workspace CLI. --dry-run (default): print the RepairPlan diff, write nothing.
// --apply: back up, apply atomically, append to .finance-meta/logs/repair-log.csv. Idempotent.

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: repair-workspace --workspace <path> [--dry-run | --apply]\n".utf8))
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

do {
    let service = try RepairService()
    if apply {
        let entries = try service.apply(workspaceURL: root)
        if entries.isEmpty {
            print("repair-workspace: nothing to repair ✓")
        } else {
            print("repair-workspace: applied \(entries.count) repair(s)")
            for entry in entries { print("  [\(entry.result.rawValue)] \(entry.actionKind): \(entry.targetFile)") }
        }
    } else {
        let plan = try service.plan(workspaceURL: root)
        if plan.actions.isEmpty {
            print("repair-workspace (dry-run): nothing to repair ✓")
        } else {
            print("repair-workspace (dry-run): \(plan.actions.count) repair(s) — no files written")
            for diff in plan.diffs { print("  \(diff.filePath): \(diff.before) → \(diff.after)") }
            print("Re-run with --apply to perform these repairs.")
        }
    }
} catch {
    FileHandle.standardError.write(Data("repair-workspace failed: \(error)\n".utf8))
    exit(1)
}
