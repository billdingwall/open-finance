import Foundation
import FinanceWorkspaceKit

// T024 — Create the standard folder tree + seed files (idempotent). contracts/cli-scripts.md.
// `--workspace` points at the Finance/ workspace directory (created if missing).

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: bootstrap-workspace --workspace <path>\n".utf8))
    exit(2)
}

var workspacePath: String?
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "-h", "--help": usage()
    default: break
    }
}

guard let workspacePath else { usage() }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

do {
    let outcome = try WorkspaceProvisioner().provision(at: root)
    if outcome.didCreateAnything {
        print("bootstrap-workspace: provisioned \(root.path)")
        print("  folders created: \(outcome.createdFolders.count)")
        print("  files created:   \(outcome.createdFiles.count)")
    } else {
        print("bootstrap-workspace: \(root.path) already complete (nothing to do)")
    }
} catch {
    FileHandle.standardError.write(Data("bootstrap-workspace failed: \(error)\n".utf8))
    exit(1)
}
