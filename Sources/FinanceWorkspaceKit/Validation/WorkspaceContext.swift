import Foundation

// T008 — The parsed workspace: the aggregate that validation predicates read for both
// per-file checks and cross-file reference lookups. Built by WorkspaceParser (T018).

public struct WorkspaceContext: Sendable {
    public let workspaceURL: URL
    public let parseResults: [CSVParseResult]
    public let notes: [NoteRecord]
    /// Discovered `.csv` files that did not classify to any managed schema (VAL-FILE-002).
    public let unrecognizedFiles: [String]

    public init(workspaceURL: URL, parseResults: [CSVParseResult], notes: [NoteRecord],
                unrecognizedFiles: [String] = []) {
        self.workspaceURL = workspaceURL
        self.parseResults = parseResults
        self.notes = notes
        self.unrecognizedFiles = unrecognizedFiles
    }

    /// All parse/normalization warnings across every file (lifted into the issue stream in US2).
    public var allWarnings: [ParseWarning] { parseResults.flatMap(\.warnings) }

    /// Parsed results for a given file-type key (e.g. "registry", "transactions").
    public func results(ofType fileTypeKey: String) -> [CSVParseResult] {
        parseResults.filter { $0.fileTypeKey == fileTypeKey }
    }

    /// All typed records of a file-type key, flattened across files (e.g. all monthly ledgers).
    public func records(ofType fileTypeKey: String) -> [ParsedRecord] {
        results(ofType: fileTypeKey).flatMap(\.records)
    }

    /// The set of string values present in `column` across all records of a file-type key —
    /// the building block for cross-file reference checks (US2).
    public func identifierSet(fileTypeKey: String, column: String) -> Set<String> {
        var ids = Set<String>()
        for record in records(ofType: fileTypeKey) {
            if case let .string(value)? = record.fields[column]?.typed { ids.insert(value) }
        }
        return ids
    }
}
