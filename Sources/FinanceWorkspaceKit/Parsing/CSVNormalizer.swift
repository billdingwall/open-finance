import Foundation

// T015 — Normalize raw string cells to typed values. A value that cannot convert yields a
// PARTIAL record (clarify Q1): the field is nulled + flagged invalid, the rest type normally,
// and a ParseWarning is emitted. Never flips amount signs (sign-flip is Phase 6 import-time).

public struct CSVNormalizer: Sendable {

    public init() {}

    private static let posix = Locale(identifier: "en_US_POSIX")

    // Formatters are constructed per call (Foundation formatters are not Sendable / not
    // thread-safe to share). Parsing is sequential per file, so the cost is negligible.
    private static func parseDate(_ value: String) -> Date? {
        let f = DateFormatter()
        f.locale = posix
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: value) { return d }
        return ISO8601DateFormatter().date(from: value)
    }

    /// Normalize one row's raw cells against `schema`. `raw` contains only canonical columns
    /// present in the file's header (missing-header handling happens in the parser).
    public func normalize(raw: [String: String], schema: CSVSchema,
                          file: String, row: Int) -> (record: ParsedRecord, warnings: [ParseWarning]) {
        var fields: [String: FieldValue] = [:]
        var warnings: [ParseWarning] = []

        for (name, column) in schema.columns {
            guard let rawValue = raw[name] else { continue }   // column absent from header
            let value = rawValue.trimmingCharacters(in: .whitespaces)

            if value.isEmpty {
                if column.required {
                    warnings.append(.init(file: file, row: row, column: name,
                                          kind: .missingRequiredValue,
                                          message: "required column '\(name)' is empty"))
                    fields[name] = FieldValue(raw: rawValue, typed: nil, isValid: false)
                } else {
                    fields[name] = FieldValue(raw: rawValue, typed: nil, isValid: true)  // valid null
                }
                continue
            }

            let (typed, warningKind, detail) = convert(value, type: column.type, enumValues: column.values)
            if let typed {
                fields[name] = FieldValue(raw: rawValue, typed: typed, isValid: true)
            } else {
                warnings.append(.init(file: file, row: row, column: name,
                                      kind: warningKind ?? .invalidEnum, message: detail))
                fields[name] = FieldValue(raw: rawValue, typed: nil, isValid: false)
            }
        }

        return (ParsedRecord(fields: fields, sourceFile: file, sourceRow: row), warnings)
    }

    private func convert(_ value: String, type: ColumnType,
                         enumValues: [String]?) -> (TypedValue?, ParseWarning.Kind?, String) {
        switch type {
        case .string:
            return (.string(value), nil, "")
        case .integer:
            if let i = Int(value) { return (.integer(i), nil, "") }
            return (nil, .invalidInteger, "'\(value)' is not an integer")
        case .decimal:
            if let d = Decimal(string: value, locale: Self.posix) { return (.decimal(d), nil, "") }
            return (nil, .invalidDecimal, "'\(value)' is not a decimal")
        case .date:
            if let date = Self.parseDate(value) { return (.date(date), nil, "") }
            return (nil, .invalidDate, "'\(value)' is not an ISO-8601 / yyyy-MM-dd date")
        case .boolean:
            switch value.lowercased() {
            case "true", "1", "yes", "y": return (.boolean(true), nil, "")
            case "false", "0", "no", "n": return (.boolean(false), nil, "")
            default: return (nil, .invalidBoolean, "'\(value)' is not a boolean")
            }
        case .enumerated:
            if let values = enumValues, values.contains(value) { return (.string(value), nil, "") }
            return (nil, .invalidEnum, "'\(value)' is not one of \(enumValues ?? [])")
        }
    }
}
