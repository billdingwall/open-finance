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

func money(_ value: Decimal) -> String { String(format: "%@%.2f", value < 0 ? "-" : "", abs(NSDecimalNumber(decimal: value).doubleValue)) }
func padR(_ text: String, _ width: Int) -> String { text.count >= width ? text : text + String(repeating: " ", count: width - text.count) }
func padL(_ text: String, _ width: Int) -> String { text.count >= width ? text : String(repeating: " ", count: width - text.count) + text }

let context = try WorkspaceParser().parse(workspaceURL: root)
let goals = SavingsGoalEngine().projectGoals(context, asOf: asOf)

let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
print("Savings goals — as of \(iso.string(from: asOf))")
print(String(repeating: "─", count: 84))
print(padR("GOAL", 22) + padL("BALANCE", 13) + padL("TARGET", 13) + padL("GAP", 13) + padL("RATE/mo", 12) + "  MONTHS")
for goal in goals {
    let rate = goal.trailingContributionRate.value.map { money($0) } ?? "—"
    let months = goal.isCompleteDerived ? "done" : (goal.monthsToGoal.map(String.init) ?? "n/a")
    let src = goal.balanceSource == .snapshot ? "" : " ~ledger"
    print(padR(goal.name, 22) + padL(money(goal.currentBalance), 13) + padL(money(goal.targetAmount), 13)
          + padL(money(goal.gapToTarget), 13) + padL(rate, 12) + "  " + months + src)
}
print(String(repeating: "─", count: 84))
print("\(goals.count) active goal(s); \(goals.filter { $0.isCompleteDerived }.count) at/over target")
