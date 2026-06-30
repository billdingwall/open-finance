import Foundation

// T023 — File-level rules computed by the engine (value-level conditions — invalid
// date/decimal/enum, missing header, etc. — arrive via lifted parse warnings, clarify Q3).
// Wired: missing required file (001), unknown file type (002), invalid transactions file name (003).
// Pending: duplicate monthly file (004).

enum FileRules {

    static func evaluate(_ context: WorkspaceContext) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let fm = FileManager.default

        // VAL-FILE-001 — missing required file.
        if let rule = RuleCatalog.rule("VAL-FILE-001") {
            for required in WorkspaceLayout.requiredFiles
            where !fm.fileExists(atPath: context.workspaceURL.appendingPathComponent(required).path) {
                issues.append(rule.makeIssue(file: required, detail: "required file '\(required)' is missing"))
            }
        }

        // VAL-FILE-002 — discovered .csv that classifies to no managed schema.
        if let rule = RuleCatalog.rule("VAL-FILE-002") {
            for file in context.unrecognizedFiles {
                issues.append(rule.makeIssue(file: file, detail: "'\(file)' is not a recognized managed file type"))
            }
        }

        // VAL-FILE-003 — a monthly ledger file whose name is not YYYY-MM.csv.
        if let rule = RuleCatalog.rule("VAL-FILE-003") {
            for result in context.parseResults where result.fileTypeKey == "transactions" {
                let name = (result.filePath as NSString).lastPathComponent
                if !Self.isValidMonthlyName(name) {
                    issues.append(rule.makeIssue(file: result.filePath,
                        detail: "transactions file '\(name)' should be named YYYY-MM.csv"))
                }
            }
        }

        return issues
    }

    /// `YYYY-MM.csv` with a 01–12 month.
    static func isValidMonthlyName(_ name: String) -> Bool {
        let parts = name.replacingOccurrences(of: ".csv", with: "").split(separator: "-")
        guard name.hasSuffix(".csv"), parts.count == 2,
              parts[0].count == 4, Int(parts[0]) != nil,
              parts[1].count == 2, let month = Int(parts[1]), (1...12).contains(month) else { return false }
        return true
    }
}
