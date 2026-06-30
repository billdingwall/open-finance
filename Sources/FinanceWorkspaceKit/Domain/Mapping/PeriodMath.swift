import Foundation

// T008 — Shared period/date helpers. A fixed Gregorian/UTC calendar keeps every projection
// deterministic under an injected as-of date (research R2/R3/R9). Periods are "YYYY-MM" strings.

public enum PeriodMath {

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// "YYYY-MM" for a date.
    public static func month(_ date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    /// "YYYY-MM" for the as-of date (the "current month").
    public static func asOfMonth(_ asOf: Date) -> String { month(asOf) }

    /// True when `date` is within the YTD window: Jan 1 of `taxYear` through the end of the
    /// as-of month (inclusive). FR-001/R3.
    public static func isInYTD(_ date: Date, taxYear: Int, asOf: Date) -> Bool {
        guard let start = calendar.date(from: DateComponents(year: taxYear, month: 1, day: 1)),
              let endExclusive = startOfMonthAfter(asOf) else { return false }
        return date >= start && date < endExclusive
    }

    /// First instant of the month following the as-of month.
    static func startOfMonthAfter(_ asOf: Date) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: asOf)
        guard let firstOfMonth = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) else { return nil }
        return calendar.date(byAdding: .month, value: 1, to: firstOfMonth)
    }

    /// The `count` "YYYY-MM" strings ending at (and including) the as-of month, oldest first.
    public static func trailingMonths(endingAt asOf: Date, count: Int) -> [String] {
        let comps = calendar.dateComponents([.year, .month], from: asOf)
        guard count > 0, let anchor = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) else { return [] }
        return (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .month, value: -back, to: anchor).map(month)
        }
    }
}
