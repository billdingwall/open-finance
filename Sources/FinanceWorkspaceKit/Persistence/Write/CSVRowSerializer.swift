import Foundation

// Phase 6 (007) — the inverse of `RecordMappers` at the text layer. `applyDiffs` edits only the
// changed data rows of a canonical CSV, preserving the leading `# schema_version: N` comment(s),
// the header row, and every untouched row byte-for-byte (research D2, guarantees S2/S4). Entity →
// row serialization (`row(_:)`) is added per-entity in US1 (T011); the byte-level editor here is
// entity-agnostic and underpins every write.

public enum CSVRowSerializer {

    // MARK: - Value → canonical row (T011)
    //
    // Column order is authoritative from the file's own header row (the JSON schema stores columns
    // in an *unordered* dictionary, so it cannot supply order). Edit forms build the typed
    // `[column: value]` field dictionary; this renders it into a canonical, CSV-escaped line.

    /// The canonical column order for a file, read from its header row (skipping `#` comments).
    public static func header(of fileText: String) -> [String]? {
        for line in fileText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            return line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }

    /// Render `fields` (canonical column → value) as one CSV line ordered by `header`.
    public static func row(fields: [String: String], header: [String]) -> String {
        header.map { escape(fields[$0] ?? "") }.joined(separator: ",")
    }

    /// RFC-4180-style minimal escaping: quote a field containing a comma, quote, or newline.
    public static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Row-diff application

    /// Apply row diffs to existing CSV `fileText`, editing only the referenced data rows.
    /// - Comment lines (leading `#…`) and the header row are preserved verbatim.
    /// - `.modify`/`.delete` target a 1-based data-row index and assert `before` still matches.
    /// - `.add` rows are appended after the existing data rows, in diff order.
    /// Returns the new file text. With an empty diff list the input is returned unchanged (S2).
    public static func applyDiffs(_ diffs: [WriteRowDiff], to fileText: String,
                                  relativePath: String = "") throws -> String {
        guard !diffs.isEmpty else { return fileText }

        let hadTrailingNewline = fileText.hasSuffix("\n")
        let (preamble, initialData) = partition(fileText)
        var dataRows = initialData

        // Modify/delete highest-index-first so earlier indices stay valid; then append adds in order.
        for diff in editsHighestFirst(diffs) {
            try applyEdit(diff, to: &dataRows, relativePath: relativePath)
        }
        for diff in diffs {
            if case .add(let after) = diff.kind { dataRows.append(after) }
        }

        let joined = (preamble + dataRows).joined(separator: "\n")
        return hadTrailingNewline ? joined + "\n" : joined
    }

    /// Split file text into (leading comments + header) and the data rows.
    private static func partition(_ fileText: String) -> (preamble: [String], dataRows: [String]) {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var headerEndIndex = 0
        while headerEndIndex < lines.count,
              lines[headerEndIndex].trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            headerEndIndex += 1
        }
        guard headerEndIndex < lines.count else { return (lines, []) }   // no header row present
        let prefixCount = headerEndIndex + 1                             // comments + header
        return (Array(lines[..<prefixCount]), Array(lines[prefixCount...]))
    }

    /// The modify/delete diffs, ordered by descending row index.
    private static func editsHighestFirst(_ diffs: [WriteRowDiff]) -> [WriteRowDiff] {
        diffs.filter { if case .add = $0.kind { return false } else { return true } }
            .sorted { ($0.rowRef ?? 0) > ($1.rowRef ?? 0) }
    }

    /// Apply one modify/delete diff to `dataRows` in place, asserting the `before` still matches.
    private static func applyEdit(_ diff: WriteRowDiff, to dataRows: inout [String],
                                  relativePath: String) throws {
        guard let ref = diff.rowRef else { return }
        let idx = ref - 1
        guard idx >= 0 && idx < dataRows.count else {
            throw WriteError.rowRefOutOfRange(path: relativePath, rowRef: ref)
        }
        switch diff.kind {
        case .modify(let before, let after):
            guard dataRows[idx] == before else { throw WriteError.rowMismatch(path: relativePath, rowRef: ref) }
            dataRows[idx] = after
        case .delete(let before):
            guard dataRows[idx] == before else { throw WriteError.rowMismatch(path: relativePath, rowRef: ref) }
            dataRows.remove(at: idx)
        case .add:
            break
        }
    }
}
