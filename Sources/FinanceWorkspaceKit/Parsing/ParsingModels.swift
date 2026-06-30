import Foundation

// T006 — Parsing-layer value types (specs/003 data-model.md).
// Files → typed domain records. A bad field yields a *partial record* (clarify Q1):
// the field is nulled + flagged invalid, the rest of the row types normally.

// MARK: - Schema

public enum ColumnType: String, Codable, Sendable {
    case string, decimal, date, boolean, integer
    case enumerated = "enum"
}

public struct ColumnDefinition: Codable, Sendable {
    public let type: ColumnType
    public let required: Bool
    public let values: [String]?        // permitted set when `type == .enumerated`
    public let references: String?      // "<file>#<column>" cross-file reference target

    public init(type: ColumnType, required: Bool, values: [String]? = nil, references: String? = nil) {
        self.type = type
        self.required = required
        self.values = values
        self.references = references
    }

    private enum CodingKeys: String, CodingKey { case type, required, values, references }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ColumnType.self, forKey: .type)
        self.required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        self.values = try container.decodeIfPresent([String].self, forKey: .values)
        self.references = try container.decodeIfPresent(String.self, forKey: .references)
    }
}

/// One canonical managed file type. Loaded from the bundled JSON schemas (authoritative at runtime).
public struct CSVSchema: Codable, Sendable {
    public let file: String             // e.g. "Accounts/accounts.csv"
    public let domain: String
    public let subtype: String          // the file-type key, e.g. "registry", "transactions"
    public let schemaVersion: Int
    public let columns: [String: ColumnDefinition]

    /// Stable key used by the registry and validation.
    public var fileTypeKey: String { subtype }

    private enum CodingKeys: String, CodingKey {
        case file, domain, subtype, columns
        case schemaVersion = "schema_version"
    }
}

// MARK: - Parsed records

/// A normalized field value (or a flagged null when the raw value could not be converted).
public enum TypedValue: Sendable, Equatable {
    case string(String)
    case decimal(Decimal)
    case date(Date)
    case boolean(Bool)
    case integer(Int)
}

public struct FieldValue: Sendable, Equatable {
    public let raw: String
    public let typed: TypedValue?       // nil when invalid, or a legitimately blank optional
    public let isValid: Bool

    public init(raw: String, typed: TypedValue?, isValid: Bool) {
        self.raw = raw
        self.typed = typed
        self.isValid = isValid
    }
}

/// One typed row. Retained even when partially invalid (clarify Q1).
public struct ParsedRecord: Sendable, Equatable {
    public let fields: [String: FieldValue]
    public let sourceFile: String
    public let sourceRow: Int           // 1-based data-row index

    public init(fields: [String: FieldValue], sourceFile: String, sourceRow: Int) {
        self.fields = fields
        self.sourceFile = sourceFile
        self.sourceRow = sourceRow
    }

    public var hasInvalidField: Bool { fields.values.contains { !$0.isValid } }
}

// MARK: - Warnings

public struct ParseWarning: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case invalidDate, invalidDecimal, invalidInteger, invalidBoolean, invalidEnum
        case unknownColumn, missingHeader, missingRequiredValue, malformedRow
        case schemaVersionMismatch, missingSchemaVersion
    }
    public let file: String
    public let row: Int?                // nil = file-level
    public let column: String?
    public let kind: Kind
    public let message: String

    public init(file: String, row: Int?, column: String?, kind: Kind, message: String) {
        self.file = file
        self.row = row
        self.column = column
        self.kind = kind
        self.message = message
    }
}

public struct CSVParseResult: Sendable {
    public let fileTypeKey: String
    public let filePath: String
    public let records: [ParsedRecord]
    public let warnings: [ParseWarning]
    public let schemaVersionFound: Int?     // nil = marker absent

    public init(fileTypeKey: String, filePath: String, records: [ParsedRecord],
                warnings: [ParseWarning], schemaVersionFound: Int?) {
        self.fileTypeKey = fileTypeKey
        self.filePath = filePath
        self.records = records
        self.warnings = warnings
        self.schemaVersionFound = schemaVersionFound
    }
}

// MARK: - Markdown notes (metadata-only in v1)

public enum FrontMatterValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case list([String])

    public var stringValue: String? { if case let .string(value) = self { return value }; return nil }
    public var intValue: Int? {
        if case let .number(number) = self { return Int(number) }
        if case let .string(value) = self { return Int(value) }
        return nil
    }
    public var listValue: [String]? {
        switch self {
        case let .list(items): return items
        case let .string(value): return [value]
        default: return nil
        }
    }
}

public struct FrontMatter: Sendable, Equatable {
    public let values: [String: FrontMatterValue]
    public init(values: [String: FrontMatterValue]) { self.values = values }
    public subscript(_ key: String) -> FrontMatterValue? { values[key] }
}

public struct NoteRecord: Sendable, Equatable {
    public let noteType: String
    public let period: String?
    public let linkedEntityIDs: [String]
    public let linkedAccountIDs: [String]
    public let linkedSleeveIDs: [String]
    public let taxYear: Int?
    public let body: String
    public let sourceFile: String
    public let frontMatterPresent: Bool

    public init(noteType: String, period: String?, linkedEntityIDs: [String],
                linkedAccountIDs: [String], linkedSleeveIDs: [String], taxYear: Int?,
                body: String, sourceFile: String, frontMatterPresent: Bool) {
        self.noteType = noteType
        self.period = period
        self.linkedEntityIDs = linkedEntityIDs
        self.linkedAccountIDs = linkedAccountIDs
        self.linkedSleeveIDs = linkedSleeveIDs
        self.taxYear = taxYear
        self.body = body
        self.sourceFile = sourceFile
        self.frontMatterPresent = frontMatterPresent
    }
}
