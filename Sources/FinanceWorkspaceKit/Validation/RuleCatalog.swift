import Foundation

// T022 — The validation rule catalog as data. One entry per defined condition
// (`VAL-<TIER>-<NNN>`), each carrying tier + severity + repair class + message template
// (contracts/validation-rule-catalog.md). Predicates live in the Rules/ files and the engine;
// classification is centralized here so it stays consistent.

public enum RuleCatalog {

    public static let all: [ValidationRule] = [
        // File-level
        rule("VAL-FILE-001", .file, .error,   .auto,   "required file is missing"),
        rule("VAL-FILE-002", .file, .warning, .none,   "unknown managed file type"),
        rule("VAL-FILE-003", .file, .warning, .none,   "invalid file name"),
        rule("VAL-FILE-004", .file, .error,   .manual, "duplicate monthly transaction file"),
        rule("VAL-FILE-005", .file, .error,   .manual, "required column missing from header"),
        rule("VAL-FILE-006", .file, .warning, .manual, "invalid date value"),
        rule("VAL-FILE-007", .file, .warning, .manual, "invalid decimal value"),
        rule("VAL-FILE-008", .file, .warning, .manual, "missing required front matter"),
        rule("VAL-FILE-009", .file, .warning, .manual, "invalid enum value"),
        rule("VAL-FILE-010", .file, .warning, .manual, "invalid integer value"),
        rule("VAL-FILE-011", .file, .warning, .manual, "required value is empty"),
        rule("VAL-FILE-012", .file, .warning, .auto,   "unknown column in header"),
        rule("VAL-FILE-013", .file, .warning, .none,   "malformed row"),
        rule("VAL-FILE-014", .file, .info,    .none,   "schema_version mismatch — route to migration"),
        rule("VAL-FILE-015", .file, .info,    .auto,   "missing schema_version marker"),
        // Cross-file
        rule("VAL-CROSS-001", .crossFile, .warning, .manual, "unknown category reference"),
        rule("VAL-CROSS-002", .crossFile, .error,   .manual, "unknown account-group reference"),
        rule("VAL-CROSS-003", .crossFile, .error,   .manual, "unknown account reference"),
        rule("VAL-CROSS-004", .crossFile, .error,   .manual, "unknown asset reference"),
        rule("VAL-CROSS-005", .crossFile, .error,   .manual, "unknown liability reference"),
        rule("VAL-CROSS-006", .crossFile, .error,   .manual, "unknown portfolio reference"),
        rule("VAL-CROSS-007", .crossFile, .error,   .manual, "unknown sleeve reference"),
        rule("VAL-CROSS-008", .crossFile, .warning, .manual, "unknown goal reference"),
        rule("VAL-CROSS-009", .crossFile, .info,    .none,   "missing benchmark data"),
        rule("VAL-CROSS-010", .crossFile, .error,   .manual, "duplicate transaction ID"),
        rule("VAL-CROSS-011", .crossFile, .warning, .none,   "orphan note link"),
        // Domain
        rule("VAL-DOMAIN-001", .domain, .warning, .none,   "budget period without budget rows"),
        rule("VAL-DOMAIN-002", .domain, .warning, .manual, "goal contribution without goal"),
        rule("VAL-DOMAIN-003", .domain, .error,   .manual, "asset without account"),
        rule("VAL-DOMAIN-004", .domain, .error,   .manual, "trade without a sending or receiving asset"),
        rule("VAL-DOMAIN-005", .domain, .error,   .manual, "multi-entry transfer group does not net to zero"),
        rule("VAL-DOMAIN-006", .domain, .error,   .manual, "gross/net group does not reconcile"),
        rule("VAL-DOMAIN-007", .domain, .warning, .manual, "tax payment outside tax year"),
        rule("VAL-DOMAIN-008", .domain, .error,   .manual, "business transaction with unknown account-group"),
    ]

    private static let byId: [String: ValidationRule] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func rule(_ id: String) -> ValidationRule? { byId[id] }

    /// The catalog rule a lifted parse/normalization warning maps to (clarify Q3 — unified stream).
    public static func rule(forParseWarning kind: ParseWarning.Kind) -> ValidationRule {
        let id: String
        switch kind {
        case .invalidDate:            id = "VAL-FILE-006"
        case .invalidDecimal:         id = "VAL-FILE-007"
        case .invalidEnum:            id = "VAL-FILE-009"
        case .invalidInteger:         id = "VAL-FILE-010"
        case .invalidBoolean:         id = "VAL-FILE-010"
        case .missingRequiredValue:   id = "VAL-FILE-011"
        case .missingHeader:          id = "VAL-FILE-005"
        case .unknownColumn:          id = "VAL-FILE-012"
        case .malformedRow:           id = "VAL-FILE-013"
        case .schemaVersionMismatch:  id = "VAL-FILE-014"
        case .missingSchemaVersion:   id = "VAL-FILE-015"
        }
        return byId[id] ?? rule("VAL-FILE-013", .file, .warning, .none, kind.rawValue)
    }

    private static func rule(_ id: String, _ tier: ValidationTier, _ severity: ValidationSeverity,
                             _ repairClass: RepairClass, _ message: String) -> ValidationRule {
        ValidationRule(id: id, tier: tier, severity: severity, repairClass: repairClass,
                       messageTemplate: message)
    }
}

public extension ValidationRule {
    /// Build a concrete issue instance from this rule's metadata.
    func makeIssue(file: String, row: Int? = nil, column: String? = nil,
                   detail: String? = nil) -> ValidationIssue {
        ValidationIssue(ruleId: id, tier: tier, severity: severity, repairClass: repairClass,
                        message: detail ?? messageTemplate, filePath: file, rowRef: row, column: column)
    }
}
