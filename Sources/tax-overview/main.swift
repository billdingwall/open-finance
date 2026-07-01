// tax-overview CLI (US2 / T021) — print the TaxEngine read model. US3 extends this with the
// deduction summary, tax estimate, prep checklist, and the two safe writes.
// usage: tax-overview --workspace <path> [--tax-year YYYY]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}

var workspacePath: String?
var taxYearArg: Int?
var args = Array(CommandLine.arguments.dropFirst())
let usage = "usage: tax-overview --workspace <path> [--tax-year YYYY]"
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--tax-year":
        guard let raw = args.first, let year = Int(raw) else { fail("invalid --tax-year", code: 2) }
        taxYearArg = year; args.removeFirst()
    case "-h", "--help": fail(usage, code: 0)
    default: break
    }
}
guard let workspacePath else { fail(usage, code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

func money(_ v: Decimal) -> String { String(format: "%@%.2f", v < 0 ? "-" : "", abs(NSDecimalNumber(decimal: v).doubleValue)) }
func pct(_ v: Decimal) -> String { String(format: "%.1f%%", NSDecimalNumber(decimal: v * 100).doubleValue) }
func padR(_ t: String, _ w: Int) -> String { t.count >= w ? t : t + String(repeating: " ", count: w - t.count) }
func padL(_ t: String, _ w: Int) -> String { t.count >= w ? t : String(repeating: " ", count: w - t.count) + t }

let context = try WorkspaceParser().parse(workspaceURL: root)
let settings = (try? SettingsStore().read(workspaceURL: root)) ?? .defaults()
let taxYear = taxYearArg ?? settings.taxYear
let projection = TaxEngine().project(context, taxYear: taxYear)

print("Tax overview — tax year \(taxYear)")
print(String(repeating: "─", count: 80))
print(padR("ACCOUNT", 20) + padL("TAXABLE INC", 14) + padL("TAXES PAID", 13) + padL("EFF RATE", 10) + padL("DIVIDENDS", 12) + padL("INTEREST", 11))
for a in projection.accounts {
    let rate = a.effectiveRate.map { pct($0) } ?? "—"
    print(padR(a.accountId, 20) + padL(money(a.ytdTaxableIncome), 14) + padL(money(a.taxesPaid), 13)
          + padL(rate, 10) + padL(money(a.dividendIncome), 12) + padL(money(a.interestIncome), 11))
}
print(String(repeating: "─", count: 80))
let r = projection.realized
print("Realized gain/loss \(taxYear): short-term \(money(r.shortTermGainLoss)) · long-term \(money(r.longTermGainLoss)) · total \(money(r.total)) (\(r.lots.count) lot disposals)")
