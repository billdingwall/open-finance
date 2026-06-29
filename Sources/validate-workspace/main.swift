import Foundation
import FinanceWorkspaceKit

// T031 — Parse the workspace, run the full ValidationEngine pass, print issues grouped by
// severity. Exit non-zero when any error-severity issue is present. (--json/--report: TODO.)

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
    let context = try WorkspaceParser().parse(workspaceURL: root)
    let result = ValidationEngine().validate(context)

    let totalRecords = context.parseResults.reduce(0) { $0 + $1.records.count }
    print("validate-workspace: \(root.path)")
    print("  files parsed:  \(context.parseResults.count)   notes: \(context.notes.count)   records: \(totalRecords)")
    print("  issues: \(result.errorCount) error, \(result.warningCount) warning, \(result.infoCount) info")

    for severity in [ValidationSeverity.error, .warning, .info] {
        let issues = result.bySeverity[severity] ?? []
        guard !issues.isEmpty else { continue }
        print("  [\(severity.rawValue)]")
        for issue in issues.sorted(by: { $0.ruleId < $1.ruleId }) {
            let loc = issue.rowRef.map { ":row \($0)" } ?? ""
            let col = issue.column.map { " [\($0)]" } ?? ""
            print("    \(issue.ruleId) \(issue.filePath)\(loc)\(col): \(issue.message)")
        }
    }
    if result.issues.isEmpty { print("  clean ✓") }

    exit(result.hasErrors ? 1 : 0)
} catch {
    FileHandle.standardError.write(Data("validate-workspace failed: \(error)\n".utf8))
    exit(1)
}
