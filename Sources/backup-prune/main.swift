import Foundation
import FinanceWorkspaceKit

// Phase 7 (008) US6 T047 — backup-prune CLI. --dry-run (default): print the prune plan, delete
// nothing. --apply: delete backups beyond the retention policy (keep last 10 per file OR < 30 days).

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: backup-prune --workspace <path> [--dry-run | --apply]\n".utf8))
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
let backupsDir = URL(fileURLWithPath: workspacePath, isDirectory: true)
    .appendingPathComponent(".finance-meta/backups", isDirectory: true)

do {
    let service = BackupPruneService(backupsDir: backupsDir)
    if apply {
        let removed = try service.prune()
        print("backup-prune: removed \(removed) backup(s) beyond retention; the rest kept.")
    } else {
        let plan = try service.plan()
        if plan.prune.isEmpty {
            print("backup-prune (dry-run): nothing to prune — \(plan.keep.count) backup(s) within policy ✓")
        } else {
            print("backup-prune (dry-run): \(plan.prune.count) backup(s) beyond policy — no files deleted")
            for url in plan.prune { print("  \(url.lastPathComponent)") }
            print("Re-run with --apply to delete these.")
        }
    }
} catch {
    FileHandle.standardError.write(Data("backup-prune failed: \(error)\n".utf8))
    exit(1)
}
