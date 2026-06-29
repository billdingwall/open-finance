import Foundation

// T026 — Full-workspace validation pass (clarify Q4): file-level → cross-file → domain.
// Parse/normalization warnings are LIFTED into the same ValidationResult as file-level issues
// (clarify Q3 — single unified issue stream feeding reporting / Overview / repair).

public struct ValidationEngine: Sendable {

    public init() {}

    public func validate(_ context: WorkspaceContext) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // 1. Lift parse/normalization warnings into the unified issue stream.
        for warning in context.allWarnings {
            let rule = RuleCatalog.rule(forParseWarning: warning.kind)
            issues.append(rule.makeIssue(file: warning.file, row: warning.row,
                                         column: warning.column, detail: warning.message))
        }

        // 2. File-level → 3. cross-file → 4. domain.
        issues += FileRules.evaluate(context)
        issues += CrossFileRules.evaluate(context)
        issues += DomainRules.evaluate(context)

        return ValidationResult(issues: issues)
    }
}
