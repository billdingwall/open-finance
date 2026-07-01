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

    /// Calendar year of a date (used for tax-year anchoring).
    public static func calendarYear(_ date: Date) -> Int { calendar.component(.year, from: date) }

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

    /// The `count` "YYYY-MM" strings immediately preceding `period` (exclusive), oldest first.
    public static func previousMonths(before period: String, count: Int) -> [String] {
        let parts = period.split(separator: "-")
        guard count > 0, parts.count == 2, let year = Int(parts[0]), let monthNum = Int(parts[1]),
              let anchor = calendar.date(from: DateComponents(year: year, month: monthNum, day: 1)) else { return [] }
        return (1...count).reversed().compactMap { back in
            calendar.date(byAdding: .month, value: -back, to: anchor).map(month)
        }
    }

    /// The `count` "YYYY-MM" strings ending at (and including) the as-of month, oldest first.
    public static func trailingMonths(endingAt asOf: Date, count: Int) -> [String] {
        let comps = calendar.dateComponents([.year, .month], from: asOf)
        guard count > 0, let anchor = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) else { return [] }
        return (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .month, value: -back, to: anchor).map(month)
        }
    }

    // MARK: - Phase 4 — benchmark anchoring, CAGR, holding period (research R1/R2)

    /// Calendar-anchored start date for a benchmark window measured back from `asOf`.
    public static func windowStart(_ window: BenchmarkWindow, asOf: Date) -> Date? {
        let cal = calendar
        switch window {
        case .day:        return cal.date(byAdding: .day, value: -1, to: asOf)
        case .week:       return cal.date(byAdding: .day, value: -7, to: asOf)
        case .month:      return cal.date(byAdding: .month, value: -1, to: asOf)
        case .threeMonth: return cal.date(byAdding: .month, value: -3, to: asOf)
        case .sixMonth:   return cal.date(byAdding: .month, value: -6, to: asOf)
        case .oneYear:    return cal.date(byAdding: .year, value: -1, to: asOf)
        case .threeYear:  return cal.date(byAdding: .year, value: -3, to: asOf)
        case .fiveYear:   return cal.date(byAdding: .year, value: -5, to: asOf)
        }
    }

    /// Multi-year windows (3Y, 5Y) are annualized (CAGR); shorter windows use simple return.
    public static func isMultiYear(_ window: BenchmarkWindow) -> Bool {
        window == .threeYear || window == .fiveYear
    }

    public static func years(for window: BenchmarkWindow) -> Double {
        switch window { case .threeYear: return 3; case .fiveYear: return 5; default: return 1 }
    }

    /// Last value at or before `date` in a date/value series **already sorted ascending by date**
    /// (last-observation-carried-forward; handles weekends/holidays/gaps). Returns nil when the whole
    /// series is after `date` (insufficient history for that anchor).
    public static func lastValueOnOrBefore<T>(_ items: [T], date: Date,
                                              dateOf: (T) -> Date, valueOf: (T) -> Decimal) -> Decimal? {
        var result: Decimal?
        for item in items {
            if dateOf(item) <= date { result = valueOf(item) } else { break }
        }
        return result
    }

    /// Compound annual growth rate over `years`, as a fraction (e.g. 0.12 = 12%).
    public static func cagr(begin: Decimal, end: Decimal, years: Double) -> Decimal? {
        guard begin > 0, years > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: end).doubleValue / NSDecimalNumber(decimal: begin).doubleValue
        guard ratio > 0 else { return nil }
        return Decimal(pow(ratio, 1.0 / years) - 1.0)
    }

    /// Simple cumulative return as a fraction.
    public static func simpleReturn(begin: Decimal, end: Decimal) -> Decimal? {
        guard begin != 0 else { return nil }
        return (end - begin) / begin
    }

    public static func holdingPeriodDays(from acquired: Date, to disposed: Date) -> Int {
        calendar.dateComponents([.day], from: acquired, to: disposed).day ?? 0
    }

    /// Long-term when held more than one year (> 365 days).
    public static func isLongTerm(acquired: Date, disposed: Date) -> Bool {
        holdingPeriodDays(from: acquired, to: disposed) > 365
    }
}
