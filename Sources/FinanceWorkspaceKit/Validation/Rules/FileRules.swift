import Foundation

// T023 — File-level rules computed by the engine (the value-level conditions — invalid
// date/decimal/enum, missing header, etc. — arrive via lifted parse warnings, clarify Q3).
// Wired here: missing required file (VAL-FILE-001). Remaining file conditions
// (unknown file type, invalid file name, duplicate monthly file) are catalog metadata, pending.

enum FileRules {

    static func evaluate(_ context: WorkspaceContext) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        guard let rule = RuleCatalog.rule("VAL-FILE-001") else { return issues }
        let fm = FileManager.default
        for required in WorkspaceLayout.requiredFiles {
            let url = context.workspaceURL.appendingPathComponent(required)
            if !fm.fileExists(atPath: url.path) {
                issues.append(rule.makeIssue(file: required, detail: "required file '\(required)' is missing"))
            }
        }
        return issues
    }
}
