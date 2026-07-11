import Foundation

// Spec 010 (UV-1) — builds the WritePlan for a user reorder of account groups or accounts.
// A reorder stamps explicit, unique gap-of-10 `sort_order` values (10, 20, 30, …) across the
// whole affected scope, touching NO other cell (research R5; contracts/sort-order-column.md).
// When the file's header lacks the column, the plan extends the header and pads every data row
// outside the scope with an empty trailing cell so row/header field counts stay aligned.
// The plan flows through the standard WriteService path (gate → drift → backup → atomic apply);
// per the constitution v1.1.2 direct-manipulation carve-out it is applied without a preview sheet.

public enum ReorderPlanBuilder {

    public enum ReorderError: Error, Equatable {
        case missingHeader(path: String)
        case missingKeyColumn(path: String, column: String)
    }

    /// Build the reorder plan.
    /// - Parameters:
    ///   - orderedIds: every ID in the affected scope, in the new display order (all groups, or
    ///     all accounts of one group). Rows whose key is not listed are left untouched (other
    ///     groups' accounts) apart from column-count padding when the header gains the column.
    ///   - keyColumn: the ID column matching `orderedIds` (`account_group_id` / `account_id`).
    public static func plan(orderedIds: [String], keyColumn: String,
                            in relativePath: String, fileText: String) throws -> WritePlan {
        guard let header = CSVRowSerializer.header(of: fileText) else {
            throw ReorderError.missingHeader(path: relativePath)
        }
        guard let keyIndex = header.firstIndex(of: keyColumn) else {
            throw ReorderError.missingKeyColumn(path: relativePath, column: keyColumn)
        }

        // Header: reuse the existing `sort_order` column or extend the header with it.
        let hadColumn = header.contains("sort_order")
        let newHeader = hadColumn ? header : header + ["sort_order"]
        let headerChange: HeaderChange? = hadColumn
            ? nil
            : HeaderChange(before: headerLine(of: fileText) ?? header.joined(separator: ","),
                           after: (headerLine(of: fileText) ?? header.joined(separator: ",")) + ",sort_order")

        // Target values: gap-of-10 by position in the new order.
        let valueById = Dictionary(uniqueKeysWithValues:
            orderedIds.enumerated().map { ($0.element, String(($0.offset + 1) * 10)) })

        var diffs: [WriteRowDiff] = []
        for (rowRef, line) in dataLines(of: fileText) {
            let cells = CSVParserService.tokenize(line).first ?? []
            let key = keyIndex < cells.count
                ? cells[keyIndex].trimmingCharacters(in: .whitespaces) : ""

            let after: String
            if let newValue = valueById[key] {
                // In scope: rebuild the row against the (possibly extended) header with the
                // stamped value — every other cell keeps its parsed value.
                var fields: [String: String] = [:]
                for (idx, column) in header.enumerated() where idx < cells.count {
                    fields[column] = cells[idx]
                }
                fields["sort_order"] = newValue
                after = CSVRowSerializer.row(fields: fields, header: newHeader)
            } else if !hadColumn {
                // Out of scope, but the header gained a column: pad with an empty trailing cell.
                after = line + ","
            } else {
                continue
            }
            if after != line {
                diffs.append(WriteRowDiff(rowRef: rowRef, kind: .modify(before: line, after: after)))
            }
        }

        return WritePlan(intent: .edit, changes: [
            FileChange(relativePath: relativePath, expectedHash: nil, rowDiffs: diffs,
                       headerChange: headerChange),
        ])
    }

    // MARK: - File-text helpers (line-level, mirroring CSVRowSerializer's partitioning)

    /// The raw header line (first non-comment, non-empty line), verbatim.
    private static func headerLine(of fileText: String) -> String? {
        for line in fileText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            return line
        }
        return nil
    }

    /// The data lines with their 1-based row refs (everything after the header line).
    private static func dataLines(of fileText: String) -> [(rowRef: Int, line: String)] {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var headerSeen = false
        var out: [(Int, String)] = []
        var rowRef = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !headerSeen {
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                headerSeen = true            // this line is the header
                continue
            }
            rowRef += 1
            if trimmed.isEmpty { continue }  // keep refs aligned with applyDiffs' line indexing
            out.append((rowRef, line))
        }
        return out
    }
}
