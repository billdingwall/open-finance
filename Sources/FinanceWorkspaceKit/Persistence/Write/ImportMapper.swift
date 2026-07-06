import Foundation

// Phase 6 (007) US2 (T022-T024) — external-CSV import. Auto-detects a column mapping to the
// canonical transaction schema, stamps one user-chosen target account on every row (clarify Q1),
// splits rows into monthly ledgers by date, and flags duplicates for per-row confirmation
// (clarify Q2). Phase 7 (008) US2 (T026/T027): the optional `description` column retains the bank
// memo; the duplicate key becomes date + amount + description within the target account, falling
// back to date + amount when either side has no description (backward-compatible — OOS-15).

public enum SignConvention: String, Sendable, Equatable {
    case negativeIsDebit    // canonical: negative = money out
    case flipped            // source uses the opposite; flip on import
}

public struct ColumnMapping: Sendable, Equatable {
    public var sourceColumns: [String]
    public var map: [String: String]          // canonical column → source column
    public var signConvention: SignConvention
    public var targetAccountId: String

    public init(sourceColumns: [String], map: [String: String],
                signConvention: SignConvention = .negativeIsDebit, targetAccountId: String = "") {
        self.sourceColumns = sourceColumns
        self.map = map
        self.signConvention = signConvention
        self.targetAccountId = targetAccountId
    }

    /// Required canonical columns the user must map before importing (FR-015).
    public static let requiredCanonical = ["date", "amount"]
    public var missingRequired: [String] { Self.requiredCanonical.filter { map[$0] == nil } }
}

public struct ImportRow: Sendable, Equatable {
    public var values: [String: String]       // canonical column → value
    public var isDuplicate: Bool
    public var included: Bool
    public init(values: [String: String], isDuplicate: Bool, included: Bool) {
        self.values = values; self.isDuplicate = isDuplicate; self.included = included
    }
}

public struct ImportBatch: Sendable, Equatable {
    public var rowsByMonth: [String: [ImportRow]]     // "YYYY-MM" → rows
    public var unparseable: [Int]                     // 1-based source rows that failed normalization
    public init(rowsByMonth: [String: [ImportRow]], unparseable: [Int]) {
        self.rowsByMonth = rowsByMonth; self.unparseable = unparseable
    }
    public var includedCount: Int { rowsByMonth.values.flatMap { $0 }.filter(\.included).count }
}

public enum ImportError: Error, Sendable, Equatable { case requiredColumnUnmapped([String]) }

public struct ImportMapper: Sendable {
    public init() {}

    // MARK: Auto-detect

    private static let synonyms: [String: [String]] = [
        "date": ["date", "posted", "posted date", "transaction date", "trans date"],
        "amount": ["amount", "value", "debit", "credit", "amt"],
        "type": ["type", "category type"],
        "description": ["description", "memo", "payee", "note", "notes", "merchant", "details", "narrative"],
    ]

    /// Best-effort mapping from external headers to canonical columns (case-insensitive).
    public func autoDetect(sourceColumns: [String]) -> ColumnMapping {
        var map: [String: String] = [:]
        for (canonical, names) in Self.synonyms {
            if let match = sourceColumns.first(where: { names.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }) {
                map[canonical] = match
            }
        }
        return ColumnMapping(sourceColumns: sourceColumns, map: map)
    }

    // MARK: Build batch

    /// Parse the external CSV under `mapping` into monthly-grouped rows, flagging duplicates against
    /// `existingTransactions` (date+amount within the target account). Throws if a required column is
    /// unmapped (FR-015).
    public func buildBatch(csv: String, mapping: ColumnMapping,
                           existingTransactions: [ParsedRecord]) throws -> ImportBatch {
        guard mapping.missingRequired.isEmpty else {
            throw ImportError.requiredColumnUnmapped(mapping.missingRequired)
        }
        // Existing rows in the target account, grouped date+amount → the set of descriptions seen
        // (absent → ""). A row is a duplicate when date+amount matches AND either side lacks a
        // description or the descriptions are equal (backward-compatible with pre-`description` data).
        var existingByDateAmount: [String: Set<String>] = [:]
        for rec in existingTransactions {
            guard rec.fields["account_id"]?.raw == mapping.targetAccountId,
                  let date = rec.fields["date"]?.raw, let amount = rec.fields["amount"]?.raw else { continue }
            let desc = rec.fields["description"]?.raw ?? ""
            existingByDateAmount[date + "|" + amount, default: []].insert(desc)
        }

        var rowsByMonth: [String: [ImportRow]] = [:]
        var unparseable: [Int] = []
        let lines = csv.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return ImportBatch(rowsByMonth: [:], unparseable: []) }
        let header = splitCSV(lines[0])
        let colIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) })

        for (offset, line) in lines.dropFirst().enumerated() {
            let sourceRow = offset + 1
            let cells = splitCSV(line)
            func value(_ canonical: String) -> String? {
                guard let src = mapping.map[canonical], let idx = colIndex[src], idx < cells.count else { return nil }
                return cells[idx].trimmingCharacters(in: .whitespaces)
            }
            guard let dateRaw = value("date"), let amountRaw = value("amount"),
                  let month = Self.month(from: dateRaw), let amount = Self.decimal(amountRaw) else {
                unparseable.append(sourceRow); continue
            }
            let signed = mapping.signConvention == .flipped ? -amount : amount
            let description = value("description") ?? ""
            var values: [String: String] = [
                "account_id": mapping.targetAccountId,
                "date": dateRaw,
                "amount": Self.plain(signed),
                "type": value("type") ?? "standard",
            ]
            if !description.isEmpty { values["description"] = description }
            values["transaction_id"] = "imp-" + UUID().uuidString.prefix(8).lowercased()
            let base = dateRaw + "|" + values["amount"]!
            let isDup: Bool = {
                guard let seen = existingByDateAmount[base] else { return false }
                // Same date+amount; a duplicate unless both sides carry differing descriptions.
                return description.isEmpty || seen.contains("") || seen.contains(description)
            }()
            rowsByMonth[month, default: []].append(ImportRow(values: values, isDuplicate: isDup, included: !isDup))
        }
        return ImportBatch(rowsByMonth: rowsByMonth, unparseable: unparseable)
    }

    // MARK: Write plan

    /// A `WritePlan` appending each month's *included* rows to its `YYYY-MM.csv` ledger.
    /// `headerFor` supplies the canonical header of an existing monthly file (or the seed header).
    public func writePlan(from batch: ImportBatch, headerFor: (String) -> [String]) -> WritePlan {
        var changes: [FileChange] = []
        for (month, rows) in batch.rowsByMonth.sorted(by: { $0.key < $1.key }) {
            let included = rows.filter(\.included)
            guard !included.isEmpty else { continue }
            let path = "Accounts/transactions/\(month).csv"
            let header = headerFor(month)
            let diffs = included.map {
                WriteRowDiff(rowRef: nil, kind: .add(after: CSVRowSerializer.row(fields: $0.values, header: header)))
            }
            changes.append(FileChange(relativePath: path, expectedHash: nil, rowDiffs: diffs))
        }
        return WritePlan(intent: .importCSV, changes: changes)
    }

    // MARK: Helpers

    func splitCSV(_ line: String) -> [String] { CSVLineSplit.fields(line) }
    static func month(from date: String) -> String? {
        let head = date.prefix(7)                       // YYYY-MM…
        return head.count == 7 && head.dropFirst(4).first == "-" ? String(head) : nil
    }
    static func decimal(_ raw: String) -> Decimal? {
        Decimal(string: raw.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: ""))
    }
    static func plain(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
}

/// Quote-aware CSV line splitter (Kit-side twin of the App's `CSVLine`).
enum CSVLineSplit {
    static func fields(_ line: String) -> [String] {
        var result: [String] = []
        var field = ""
        var insideQuotes = false
        let chars = Array(line)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if insideQuotes {
                let isEscapedQuote = char == "\"" && index + 1 < chars.count && chars[index + 1] == "\""
                if isEscapedQuote {
                    field.append("\"")
                    index += 1
                } else if char == "\"" {
                    insideQuotes = false
                } else {
                    field.append(char)
                }
            } else if char == "\"" {
                insideQuotes = true
            } else if char == "," {
                result.append(field)
                field = ""
            } else {
                field.append(char)
            }
            index += 1
        }
        result.append(field)
        return result
    }
}
