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
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: value) { return date }
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

            let conversion = convert(value, type: column.type, enumValues: column.values)
            if let typed = conversion.value {
                fields[name] = FieldValue(raw: rawValue, typed: typed, isValid: true)
            } else {
                warnings.append(.init(file: file, row: row, column: name,
                                      kind: conversion.warningKind ?? .invalidEnum, message: conversion.detail))
                fields[name] = FieldValue(raw: rawValue, typed: nil, isValid: false)
            }
        }

        return (ParsedRecord(fields: fields, sourceFile: file, sourceRow: row), warnings)
    }

    /// Outcome of converting one raw value: a typed value, or a flagged failure.
    private struct Conversion {
        let value: TypedValue?
        let warningKind: ParseWarning.Kind?
        let detail: String
        static func ok(_ value: TypedValue) -> Conversion { Conversion(value: value, warningKind: nil, detail: "") }
        static func fail(_ kind: ParseWarning.Kind, _ detail: String) -> Conversion {
            Conversion(value: nil, warningKind: kind, detail: detail)
        }
    }

    private func convert(_ value: String, type: ColumnType, enumValues: [String]?) -> Conversion {
        switch type {
        case .string:
            return .ok(.string(value))
        case .integer:
            return Int(value).map { .ok(.integer($0)) } ?? .fail(.invalidInteger, "'\(value)' is not an integer")
        case .decimal:
            return Decimal(string: value, locale: Self.posix).map { .ok(.decimal($0)) }
                ?? .fail(.invalidDecimal, "'\(value)' is not a decimal")
        case .date:
            return Self.parseDate(value).map { .ok(.date($0)) }
                ?? .fail(.invalidDate, "'\(value)' is not an ISO-8601 / yyyy-MM-dd date")
        case .boolean:
            return Self.parseBool(value).map { .ok(.boolean($0)) } ?? .fail(.invalidBoolean, "'\(value)' is not a boolean")
        case .enumerated:
            return (enumValues?.contains(value) ?? false)
                ? .ok(.string(value)) : .fail(.invalidEnum, "'\(value)' is not one of \(enumValues ?? [])")
        }
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "1", "yes", "y": return true
        case "false", "0", "no", "n": return false
        default: return nil
        }
    }
}
