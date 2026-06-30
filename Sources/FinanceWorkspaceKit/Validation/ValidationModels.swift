import Foundation

// ValidationIssue / RepairAction — defined as Phase 1 stubs (T006), made concrete in Phase 2 (T007).

public enum ValidationTier: String, Codable, Sendable, CaseIterable {
    case file, crossFile, domain
}

public enum ValidationSeverity: String, Codable, Sendable, CaseIterable {
    case error, warning, info
}

public enum RepairClass: String, Codable, Sendable, CaseIterable {
    case auto, manual, none
}

/// A single validation finding. Rule IDs follow `VAL-<TIER>-<NNN>`.
public struct ValidationIssue: Codable, Equatable, Sendable, Identifiable {
    public var ruleId: String
    public var tier: ValidationTier
    public var severity: ValidationSeverity
    public var repairClass: RepairClass
    public var message: String
    public var filePath: String
    public var rowRef: Int?
    public var column: String?

    public var id: String { "\(ruleId)@\(filePath)#\(rowRef.map(String.init) ?? "-")" }

    public init(ruleId: String, tier: ValidationTier, severity: ValidationSeverity,
                repairClass: RepairClass, message: String, filePath: String,
                rowRef: Int? = nil, column: String? = nil) {
        self.ruleId = ruleId
        self.tier = tier
        self.severity = severity
        self.repairClass = repairClass
        self.message = message
        self.filePath = filePath
        self.rowRef = rowRef
        self.column = column
    }
}

/// A deterministic, previewable repair. Applied only with user confirmation (Phase 2+).
public struct RepairAction: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case createFile, normalizeHeader, injectOptionalColumn, createFolder
    }
    public var id: String
    public var issueRef: String
    public var kind: Kind
    public var preview: String
    public var backupPath: String?
    public var appliedAt: Date?

    public init(id: String = UUID().uuidString, issueRef: String, kind: Kind,
                preview: String, backupPath: String? = nil, appliedAt: Date? = nil) {
        self.id = id
        self.issueRef = issueRef
        self.kind = kind
        self.preview = preview
        self.backupPath = backupPath
        self.appliedAt = appliedAt
    }
}

// MARK: - Phase 2 concrete types (T007)

/// Result of a full-workspace validation pass. Includes parse/normalization warnings lifted
/// into the issue stream (clarify Q3 — single unified issue stream).
public struct ValidationResult: Sendable {
    public var issues: [ValidationIssue]
    public init(issues: [ValidationIssue]) { self.issues = issues }

    public var bySeverity: [ValidationSeverity: [ValidationIssue]] {
        Dictionary(grouping: issues, by: \.severity)
    }
    public var errorCount: Int { issues.filter { $0.severity == .error }.count }
    public var warningCount: Int { issues.filter { $0.severity == .warning }.count }
    public var infoCount: Int { issues.filter { $0.severity == .info }.count }
    public var hasErrors: Bool { errorCount > 0 }
}

/// A catalog rule's metadata (`VAL-<TIER>-<NNN>`). The pure predicate that fires it is wired
/// in Phase 2 US2 (RuleCatalog) — kept out of this value type so it stays Codable/Sendable.
public struct ValidationRule: Codable, Sendable, Identifiable {
    public var id: String               // VAL-<TIER>-<NNN>
    public var tier: ValidationTier
    public var severity: ValidationSeverity
    public var repairClass: RepairClass
    public var messageTemplate: String

    public init(id: String, tier: ValidationTier, severity: ValidationSeverity,
                repairClass: RepairClass, messageTemplate: String) {
        self.id = id
        self.tier = tier
        self.severity = severity
        self.repairClass = repairClass
        self.messageTemplate = messageTemplate
    }
}

/// A before/after view of one affected row, for repair preview.
public struct RowDiff: Codable, Equatable, Sendable {
    public var filePath: String
    public var rowRef: Int?
    public var before: String
    public var after: String
    public init(filePath: String, rowRef: Int?, before: String, after: String) {
        self.filePath = filePath
        self.rowRef = rowRef
        self.before = before
        self.after = after
    }
}

/// A previewable, backed-up, atomic repair. Auto-class only; always user-confirmed.
public struct RepairPlan: Sendable {
    public var actions: [RepairAction]
    public var diffs: [RowDiff]
    public var backupPath: String?
    public var requiresConfirmation: Bool
    public init(actions: [RepairAction], diffs: [RowDiff],
                backupPath: String? = nil, requiresConfirmation: Bool = true) {
        self.actions = actions
        self.diffs = diffs
        self.backupPath = backupPath
        self.requiresConfirmation = requiresConfirmation
    }
}

/// One row written to the user-facing repair log at `.finance-meta/logs/repair-log.csv`.
public struct RepairLogEntry: Codable, Equatable, Sendable {
    public enum Result: String, Codable, Sendable { case applied, skipped, failed }
    public var timestamp: Date
    public var targetFile: String
    public var actionKind: String
    public var backupPath: String?
    public var result: Result
    public init(timestamp: Date, targetFile: String, actionKind: String,
                backupPath: String?, result: Result) {
        self.timestamp = timestamp
        self.targetFile = targetFile
        self.actionKind = actionKind
        self.backupPath = backupPath
        self.result = result
    }
}
