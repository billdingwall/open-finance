// portfolio-overview CLI (US1 / T016) — print the PortfolioEngine holdings projection.
// usage: portfolio-overview --workspace <path> [--as-of YYYY-MM-DD] [--account <id>]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}

var workspacePath: String?
var account: String?
var asOf = Date()
var args = Array(CommandLine.arguments.dropFirst())
let isoDay: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]; fmt.timeZone = TimeZone(identifier: "UTC"); return fmt
}()
let usage = "usage: portfolio-overview --workspace <path> [--as-of YYYY-MM-DD] [--account <id>]"
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--account": account = args.first; if account != nil { args.removeFirst() }
    case "--as-of":
        guard let raw = args.first, let date = isoDay.date(from: raw) else { fail("invalid --as-of (expected YYYY-MM-DD)", code: 2) }
        asOf = date; args.removeFirst()
    case "-h", "--help": fail(usage, code: 0)
    default: break
    }
}
guard let workspacePath else { fail(usage, code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

func money(_ value: Decimal) -> String {
    String(format: "%@%.2f", value < 0 ? "-" : "", abs(NSDecimalNumber(decimal: value).doubleValue))
}
func qty(_ value: Decimal) -> String { String(format: "%.4f", NSDecimalNumber(decimal: value).doubleValue) }
func pct(_ value: Decimal) -> String { String(format: "%.1f%%", NSDecimalNumber(decimal: value * 100).doubleValue) }
func padR(_ text: String, _ width: Int) -> String { text.count >= width ? text : text + String(repeating: " ", count: width - text.count) }
func padL(_ text: String, _ width: Int) -> String { text.count >= width ? text : String(repeating: " ", count: width - text.count) + text }
func valueText(_ state: ValueState) -> String { if case let .value(amount) = state { return money(amount) }; return "price n/a" }

let context = try WorkspaceParser().parse(workspaceURL: root)
let scope: HoldingsProjection.Scope = account.map { .account($0) } ?? .aggregate
let projection = PortfolioEngine().holdings(context, asOf: asOf, scope: scope)

let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
print("Portfolio holdings — as of \(iso.string(from: asOf))\(account.map { " · account \($0)" } ?? "")")
print(String(repeating: "─", count: 78))
print(padR("ASSET", 12) + padR("TICKER", 8) + padL("QTY", 12) + padL("COST BASIS", 14) + padL("VALUE", 14) + padL("UNREALIZED", 14))
for pos in projection.positions {
    print(padR(pos.assetId, 12) + padR(pos.ticker ?? "", 8) + padL(qty(pos.quantity), 12)
          + padL(money(pos.costBasis), 14) + padL(valueText(pos.currentValue), 14) + padL(valueText(pos.unrealizedGainLoss), 14))
}
print(String(repeating: "─", count: 78))
print("TOTAL priced market value \(money(projection.totalMarketValue))")
if !projection.sleeveAllocations.isEmpty {
    print("Sleeves:")
    for sleeve in projection.sleeveAllocations {
        let target = sleeve.targetWeight.map { pct($0) } ?? "—"
        let drift = sleeve.drift.map { (($0 >= 0 ? "+" : "") + pct($0)) } ?? "—"
        print("  \(padR(sleeve.name, 18)) mv \(money(sleeve.marketValue)) · actual \(pct(sleeve.actualWeight)) · target \(target) · drift \(drift)")
    }
}
if !projection.dividendTotalsByAsset.isEmpty {
    let total = projection.dividendTotalsByAsset.values.reduce(0, +)
    print("Dividends to as-of: \(money(total)) across \(projection.dividendTotalsByAsset.count) asset(s)")
}
