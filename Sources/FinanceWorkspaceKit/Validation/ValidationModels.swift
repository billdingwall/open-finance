import Foundation

// T006 — ValidationIssue / RepairAction contract stubs. Full behavior is Phase 2.

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

    public var id: String { "\(ruleId)@\(filePath)#\(rowRef.map(String.init) ?? "-")" }

    public init(ruleId: String, tier: ValidationTier, severity: ValidationSeverity,
                repairClass: RepairClass, message: String, filePath: String, rowRef: Int? = nil) {
        self.ruleId = ruleId
        self.tier = tier
        self.severity = severity
        self.repairClass = repairClass
        self.message = message
        self.filePath = filePath
        self.rowRef = rowRef
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
