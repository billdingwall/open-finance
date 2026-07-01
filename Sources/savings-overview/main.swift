// savings-overview CLI (US5 / T040) — print the SavingsGoalEngine projection.
// usage: savings-overview --workspace <path> [--as-of YYYY-MM-DD]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}

var workspacePath: String?
var asOf = Date()
var args = Array(CommandLine.arguments.dropFirst())
let isoDay: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]; fmt.timeZone = TimeZone(identifier: "UTC"); return fmt
}()
let usage = "usage: savings-overview --workspace <path> [--as-of YYYY-MM-DD]"
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--as-of":
        guard let raw = args.first, let date = isoDay.date(from: raw) else { fail("invalid --as-of (expected YYYY-MM-DD)", code: 2) }
        asOf = date; args.removeFirst()
    case "-h", "--help": fail(usage, code: 0)
    default: break
    }
}
guard let workspacePath else { fail(usage, code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

func money(_ v: Decimal) -> String { String(format: "%@%.2f", v < 0 ? "-" : "", abs(NSDecimalNumber(decimal: v).doubleValue)) }
func padR(_ t: String, _ w: Int) -> String { t.count >= w ? t : t + String(repeating: " ", count: w - t.count) }
func padL(_ t: String, _ w: Int) -> String { t.count >= w ? t : String(repeating: " ", count: w - t.count) + t }

let context = try WorkspaceParser().parse(workspaceURL: root)
let goals = SavingsGoalEngine().projectGoals(context, asOf: asOf)

let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
print("Savings goals — as of \(iso.string(from: asOf))")
print(String(repeating: "─", count: 84))
print(padR("GOAL", 22) + padL("BALANCE", 13) + padL("TARGET", 13) + padL("GAP", 13) + padL("RATE/mo", 12) + "  MONTHS")
for g in goals {
    let rate = g.trailingContributionRate.value.map { money($0) } ?? "—"
    let months = g.isCompleteDerived ? "done" : (g.monthsToGoal.map(String.init) ?? "n/a")
    let src = g.balanceSource == .snapshot ? "" : " ~ledger"
    print(padR(g.name, 22) + padL(money(g.currentBalance), 13) + padL(money(g.targetAmount), 13)
          + padL(money(g.gapToTarget), 13) + padL(rate, 12) + "  " + months + src)
}
print(String(repeating: "─", count: 84))
print("\(goals.count) active goal(s); \(goals.filter { $0.isCompleteDerived }.count) at/over target")
