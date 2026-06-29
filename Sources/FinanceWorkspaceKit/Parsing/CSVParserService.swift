import Foundation

// T014 — Parse a managed CSV into typed records. RFC-4180 quoting; tolerant of leading `#`
// comment rows (incl. `# schema_version: N`); case-insensitive, whitespace-trimmed header
// mapping; source provenance on every record; resilient per-row (a malformed row warns, the
// file continues — SC-009). Normalization (and partial records) is delegated to CSVNormalizer.

public struct CSVParserService: Sendable {

    private let coordinator: FileCoordinatorService
    private let normalizer: CSVNormalizer

    public init(coordinator: FileCoordinatorService = FileCoordinatorService(),
                normalizer: CSVNormalizer = CSVNormalizer()) {
        self.coordinator = coordinator
        self.normalizer = normalizer
    }

    public func parse(fileAt url: URL, relativePath: String, schema: CSVSchema) throws -> CSVParseResult {
        let text = try coordinator.coordinatedRead(url) { try String(contentsOf: $0, encoding: .utf8) }
        return parse(text: text, relativePath: relativePath, schema: schema)
    }

    /// Pure parse over file text — directly unit-testable without touching disk.
    public func parse(text: String, relativePath: String, schema: CSVSchema) -> CSVParseResult {
        var warnings: [ParseWarning] = []

        // 1. Strip leading `#` comment rows; capture schema_version.
        let (body, schemaVersion) = Self.stripLeadingComments(text)
        if schemaVersion == nil {
            warnings.append(.init(file: relativePath, row: nil, column: nil,
                                  kind: .missingSchemaVersion,
                                  message: "no `# schema_version` marker; assuming current"))
        } else if let v = schemaVersion, v != schema.schemaVersion {
            warnings.append(.init(file: relativePath, row: nil, column: nil,
                                  kind: .schemaVersionMismatch,
                                  message: "schema_version \(v) != registry \(schema.schemaVersion); route to migration"))
        }

        // 2. Tokenize body into records (RFC-4180).
        let rows = Self.tokenize(body).filter { !($0.count == 1 && $0[0].isEmpty) }  // drop blank lines
        guard let header = rows.first else {
            return CSVParseResult(fileTypeKey: schema.fileTypeKey, filePath: relativePath,
                                  records: [], warnings: warnings, schemaVersionFound: schemaVersion)
        }

        // 3. Map header cells → canonical column names (case-insensitive, trimmed).
        let canonicalByLower = Dictionary(uniqueKeysWithValues:
            schema.columns.keys.map { ($0.lowercased(), $0) })
        var indexToColumn: [Int: String] = [:]
        var seenColumns = Set<String>()
        for (i, cell) in header.enumerated() {
            let key = cell.trimmingCharacters(in: .whitespaces).lowercased()
            if let canonical = canonicalByLower[key] {
                indexToColumn[i] = canonical
                seenColumns.insert(canonical)
            } else if !key.isEmpty {
                warnings.append(.init(file: relativePath, row: nil, column: cell,
                                      kind: .unknownColumn,
                                      message: "header '\(cell)' is not in the \(schema.fileTypeKey) schema"))
            }
        }
        for (name, column) in schema.columns where column.required && !seenColumns.contains(name) {
            warnings.append(.init(file: relativePath, row: nil, column: name,
                                  kind: .missingHeader,
                                  message: "required column '\(name)' is missing from the header"))
        }

        // 4. Each data row → raw dict → normalize. Resilient per-row.
        var records: [ParsedRecord] = []
        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 1   // 1-based data-row index
            if row.count != header.count {
                warnings.append(.init(file: relativePath, row: rowNumber, column: nil,
                                      kind: .malformedRow,
                                      message: "row has \(row.count) fields, header has \(header.count)"))
            }
            var raw: [String: String] = [:]
            for (i, column) in indexToColumn where i < row.count {
                raw[column] = row[i]
            }
            let (record, rowWarnings) = normalizer.normalize(raw: raw, schema: schema,
                                                             file: relativePath, row: rowNumber)
            records.append(record)
            warnings.append(contentsOf: rowWarnings)
        }

        return CSVParseResult(fileTypeKey: schema.fileTypeKey, filePath: relativePath,
                              records: records, warnings: warnings, schemaVersionFound: schemaVersion)
    }

    // MARK: - Helpers

    /// Remove leading lines that start with `#`; return the remaining body + any schema_version.
    static func stripLeadingComments(_ text: String) -> (body: String, schemaVersion: Int?) {
        var lines = text.components(separatedBy: "\n")
        var version: Int?
        var idx = 0
        while idx < lines.count {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { break }
            // e.g. "# schema_version: 1"
            let stripped = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            let parts = stripped.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0].lowercased() == "schema_version", let v = Int(parts[1]) {
                version = v
            }
            idx += 1
        }
        return (lines[idx...].joined(separator: "\n"), version)
    }

    /// RFC-4180 tokenizer: handles quoted fields with embedded commas, newlines, and `""` escapes.
    static func tokenize(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 2; continue }
                    inQuotes = false; i += 1
                } else {
                    field.append(c); i += 1
                }
            } else {
                switch c {
                case "\"": inQuotes = true; i += 1
                case ",": record.append(field); field = ""; i += 1
                case "\r":
                    record.append(field); field = ""
                    records.append(record); record = []
                    i += (i + 1 < chars.count && chars[i + 1] == "\n") ? 2 : 1
                case "\n":
                    record.append(field); field = ""
                    records.append(record); record = []
                    i += 1
                default: field.append(c); i += 1
                }
            }
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}
