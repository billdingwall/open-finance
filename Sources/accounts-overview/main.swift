// accounts-overview CLI (US1 / T017) — print the AccountEngine projection for a workspace.
// usage: accounts-overview --workspace <path> [--as-of YYYY-MM-DD]
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
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--as-of":
        guard let raw = args.first, let date = isoDay.date(from: raw) else { fail("invalid --as-of (expected YYYY-MM-DD)", code: 2) }
        asOf = date; args.removeFirst()
    case "-h", "--help": fail("usage: accounts-overview --workspace <path> [--as-of YYYY-MM-DD]", code: 0)
    default: break
    }
}
guard let workspacePath else { fail("usage: accounts-overview --workspace <path> [--as-of YYYY-MM-DD]", code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

func money(_ value: Decimal) -> String {
    let num = NSDecimalNumber(decimal: value)
    return String(format: "%@%.2f", value < 0 ? "-" : "", abs(num.doubleValue))
}
func padR(_ text: String, _ width: Int) -> String { text.count >= width ? text : text + String(repeating: " ", count: width - text.count) }
func padL(_ text: String, _ width: Int) -> String { text.count >= width ? text : String(repeating: " ", count: width - text.count) + text }

do {
    let context = try WorkspaceParser().parse(workspaceURL: root)
    let settings = (try? SettingsStore().read(workspaceURL: root)) ?? .defaults()
    let overview = AccountEngine().overview(context, asOf: asOf, settings: settings)

    print("Accounts overview — as of \(overview.asOfMonth) (tax year \(overview.taxYear))")
    print(String(repeating: "─", count: 72))
    print(padR("ACCOUNT", 22) + padR("GROUP", 13) + padL("MONTH INFLOW", 14) + padL("YTD NET", 14))
    for card in overview.accounts.sorted(by: { $0.accountId < $1.accountId }) {
        let mark = card.isProjected ? "  [projected]" : ""
        print(padR(card.displayName, 22) + padR(card.accountGroup.rawValue, 13)
              + padL(money(card.monthlyInflow), 14) + padL(money(card.ytdNetIncome), 14) + mark)
    }
    print(String(repeating: "─", count: 72))
    for group in overview.groups {
        print("group \(group.accountGroupId) [\(group.groupType.rawValue)] — YTD net \(money(group.ytdNetIncome)), retained equity \(money(group.ytdRetainedEquity))")
        for pl in group.businessPL ?? [] { print("    P&L \(pl.period): \(money(pl.netIncome))") }
    }
    print(String(repeating: "─", count: 72))
    print("TOTAL month inflow \(money(overview.totalMonthlyInflow)) · YTD net \(money(overview.totalYTDNetIncome))")
    print("YTD personal inflow \(money(overview.totalYTDPersonalInflow)) · retained equity \(money(overview.totalYTDRetainedEquity))")
} catch {
    fail("accounts-overview failed: \(error)", code: 1)
}
