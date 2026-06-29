import Foundation
import FinanceWorkspaceKit

// T031 (partial — US1 parse pass). Parses the workspace and prints the parse/normalization
// warning stream grouped by file. The full three-tier ValidationEngine pass + grouped-by-severity
// summary + --json/--report land in US2/US3.

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: validate-workspace --workspace <path>\n".utf8))
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
    let parser = try WorkspaceParser()
    let context = parser.parse(workspaceURL: root)

    let totalRecords = context.parseResults.reduce(0) { $0 + $1.records.count }
    print("validate-workspace: \(root.path)")
    print("  files parsed:  \(context.parseResults.count)")
    print("  notes parsed:  \(context.notes.count)")
    print("  records typed: \(totalRecords)")

    let warnings = context.allWarnings
    if warnings.isEmpty {
        print("  parse warnings: none ✓")
    } else {
        print("  parse warnings: \(warnings.count)")
        for warning in warnings {
            let loc = warning.row.map { ":row \($0)" } ?? ""
            let col = warning.column.map { " [\($0)]" } ?? ""
            print("    - \(warning.file)\(loc)\(col) \(warning.kind): \(warning.message)")
        }
    }
    exit(warnings.isEmpty ? 0 : 0)   // parse warnings don't fail the run; error-severity gating is US2
} catch {
    FileHandle.standardError.write(Data("validate-workspace failed: \(error)\n".utf8))
    exit(1)
}
