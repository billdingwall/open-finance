import Foundation
import FinanceWorkspaceKit

// T006 — shared presentation primitives: traceability payloads, provenance, deltas, and the
// tabular formatters every view uses. Formatting only — no finance math lives here (FR-031).

// MARK: - Traceability (constitution P-V)

/// How a displayed value came to be — rendered by `ValueProvenanceLabel` (FR-013).
enum Provenance: String {
    case imported, derived, repaired
    case userEdited = "user-edited"
}

/// The traceability payload a row carries to the source inspector (FR-012/030).
struct SourceRef: Equatable {
    var filePath: String            // workspace-relative
    var rowNumber: Int?
    var rawFields: [(name: String, value: String)] = []
    var provenance: Provenance = .imported

    static func == (lhs: SourceRef, rhs: SourceRef) -> Bool {
        lhs.filePath == rhs.filePath && lhs.rowNumber == rhs.rowNumber
            && lhs.provenance == rhs.provenance
            && lhs.rawFields.map(\.name) == rhs.rawFields.map(\.name)
            && lhs.rawFields.map(\.value) == rhs.rawFields.map(\.value)
    }
}

extension UnifiedTransaction {
    /// Source reference for a ledger row, when the parser carried provenance through.
    var sourceRef: SourceRef? {
        guard let sourceFile else { return nil }
        return SourceRef(filePath: sourceFile, rowNumber: sourceRow, provenance: .imported)
    }
}

extension ValidationIssue {
    var sourceRef: SourceRef {
        SourceRef(filePath: filePath, rowNumber: rowRef, provenance: .imported)
    }
    var statusKind: StatusKind {
        switch severity {
        case .error: return .err
        case .warning: return .warn
        case .info: return .info
        }
    }
}

// MARK: - Delta (pos/neg/flat)

/// A signed change indicator; green/red are reserved for exactly this meaning.
enum Delta: Equatable {
    case pos(String)
    case neg(String)
    case flat(String)

    /// Classify a money delta, formatting with sign.
    static func of(_ value: Decimal) -> Delta {
        if value > 0 { return .pos("+" + Format.money(value)) }
        if value < 0 { return .neg(Format.money(value)) }
        return .flat(Format.money(0))
    }

    var text: String {
        switch self {
        case let .pos(text), let .neg(text), let .flat(text): return text
        }
    }
}

// MARK: - Formatters (tabular-ready strings)

enum Format {
    private static let currency: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt
    }()

    private static let wholeCurrency: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        return fmt
    }()

    static func money(_ value: Decimal) -> String {
        currency.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }

    static func moneyWhole(_ value: Decimal) -> String {
        wholeCurrency.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }

    /// Percent from a 0…1 fraction, e.g. 0.0725 → "7.3%".
    static func percent(_ fraction: Decimal, digits: Int = 1) -> String {
        let scaled = NSDecimalNumber(decimal: fraction * 100).doubleValue
        return String(format: "%.\(digits)f%%", scaled)
    }

    /// Signed percent for growth cells, e.g. "+4.2%" / "−1.3%".
    static func signedPercent(_ fraction: Decimal, digits: Int = 1) -> String {
        let scaled = NSDecimalNumber(decimal: fraction * 100).doubleValue
        return String(format: "%@%.\(digits)f%%", scaled >= 0 ? "+" : "", scaled)
    }

    static func quantity(_ value: Decimal) -> String {
        let num = NSDecimalNumber(decimal: value)
        return num.doubleValue == num.doubleValue.rounded()
            ? String(format: "%.0f", num.doubleValue)
            : String(format: "%.4f", num.doubleValue)
    }

    private static let day: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt
    }()

    static func date(_ value: Date) -> String { day.string(from: value) }

    /// "2026-06" → "Jun 2026" (falls through to the raw period on parse failure).
    static func monthName(_ period: String) -> String {
        let parts = period.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else { return period }
        let symbol = DateFormatter().shortMonthSymbols[month - 1]
        return "\(symbol) \(parts[0])"
    }
}

// MARK: - Typed-state display text

enum TypedStateText {
    static let rateNotSet = "rate not set"
    static let priceUnavailable = "price unavailable"
    static let insufficientHistory = "insufficient history"
    static let notAvailable = "n/a"
    static let dataNotAvailable = "data not available"
}
