import Foundation
import FinanceWorkspaceKit

// bootstrap-workspace — create the standard folder tree + seed files (contracts/cli-scripts.md).
// Full seeding (six accounts, default categories, schema templates) is implemented in US1 (T024);
// this entry point parses arguments and delegates so the executable exists for the toolchain.

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

// US1/T024 fills in full provisioning via WorkspaceProvisioner.
print("bootstrap-workspace: target \(root.path)")
print("Full provisioning (folder tree + seed accounts/categories/schemas) lands in US1 (T024).")
