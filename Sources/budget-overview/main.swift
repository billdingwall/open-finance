// budget-overview CLI (US2 / T024) — print the BudgetEngine projection for a workspace.
// usage: budget-overview --workspace <path> [--budget <id>] [--period YYYY-MM] [--as-of YYYY-MM-DD]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}
func money(_ value: Decimal) -> String {
    let num = NSDecimalNumber(decimal: value)
    return String(format: "%@%.2f", value < 0 ? "-" : "", abs(num.doubleValue))
}
func pct(_ value: Decimal) -> String { String(format: "%.1f%%", NSDecimalNumber(decimal: value).doubleValue) }
func padR(_ text: String, _ width: Int) -> String { text.count >= width ? text : text + String(repeating: " ", count: width - text.count) }
func padL(_ text: String, _ width: Int) -> String { text.count >= width ? text : String(repeating: " ", count: width - text.count) + text }

let isoDay: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]; fmt.timeZone = TimeZone(identifier: "UTC"); return fmt
}()

var workspacePath: String?
var budgetId: String?
var period: String?
var asOf = Date()
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--budget": budgetId = args.first; if budgetId != nil { args.removeFirst() }
    case "--period": period = args.first; if period != nil { args.removeFirst() }
    case "--as-of":
        guard let raw = args.first, let date = isoDay.date(from: raw) else { fail("invalid --as-of", code: 2) }
        asOf = date; args.removeFirst()
    case "-h", "--help": fail("usage: budget-overview --workspace <path> [--budget <id>] [--period YYYY-MM] [--as-of YYYY-MM-DD]", code: 0)
    default: break
    }
}
guard let workspacePath else { fail("usage: budget-overview --workspace <path> [--budget <id>] [--period YYYY-MM]", code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

do {
    let context = try WorkspaceParser().parse(workspaceURL: root)
    guard let budget = context.budgets.first(where: { budgetId == nil || $0.budgetId == budgetId }) else {
        fail("no budget found (define one in Budget/budgets.csv, or pass --budget)", code: 1)
    }
    let resolvedPeriod = period ?? PeriodMath.asOfMonth(asOf)
    guard let projection = BudgetEngine().overview(budgetId: budget.budgetId, period: resolvedPeriod,
                                                   in: context, asOf: asOf) else {
        fail("could not build budget projection", code: 1)
    }

    print("Budget '\(budget.name)' — \(projection.period)")
    print(String(repeating: "─", count: 78))
    print(padR("CATEGORY", 22) + padR("BEHAVIOR", 14) + padL("PLANNED", 11) + padL("ACTUAL", 11)
          + padL("VARIANCE", 11) + "  TRAILING")
    for row in projection.rows.sorted(by: { $0.categoryId < $1.categoryId }) {
        let avg = row.trailingAverage.value.map(money) ?? "—"
        print(padR(row.categoryName, 22) + padR(row.behavior.rawValue, 14) + padL(money(row.planned), 11)
              + padL(money(row.actual), 11) + padL(money(row.variance), 11)
              + "  \(avg) (\(row.trailingAverage.label))")
    }
    print(String(repeating: "─", count: 78))
    let totals = projection.totals
    print("income \(money(totals.income)) · fixed \(money(totals.fixed)) · discretionary \(money(totals.discretionary))")
    print("savings \(money(totals.savings)) · investments \(money(totals.investments)) · transfers \(money(totals.transfers))")
    print("net monthly income \(money(totals.netMonthlyIncome))")
    let mix = projection.spendMix
    print("spend mix (% of net income) — fixed \(pct(mix.fixedPct)) · discretionary \(pct(mix.discretionaryPct))")
    print("              savings \(pct(mix.savingsPct)) · investments \(pct(mix.investmentPct))")
    for contribution in projection.goalContributions {
        print("goal \(contribution.goalId): \(money(contribution.amount))")
    }
} catch {
    fail("budget-overview failed: \(error)", code: 1)
}
