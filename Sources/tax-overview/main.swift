// tax-overview CLI (US2/US3 / T021,T031) — TaxEngine read model + deduction summary, tax estimate,
// prep checklist; and the two safe writes (preview by default, --apply to write).
// usage: tax-overview --workspace <path> [--tax-year YYYY] [--seed-standard] [--close-year] [--apply]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}

var workspacePath: String?
var taxYearArg: Int?
var seedStandard = false, closeYear = false, apply = false
var args = Array(CommandLine.arguments.dropFirst())
let usage = "usage: tax-overview --workspace <path> [--tax-year YYYY] [--seed-standard] [--close-year] [--apply]"
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--tax-year":
        guard let raw = args.first, let year = Int(raw) else { fail("invalid --tax-year", code: 2) }
        taxYearArg = year; args.removeFirst()
    case "--seed-standard": seedStandard = true
    case "--close-year": closeYear = true
    case "--apply": apply = true
    case "-h", "--help": fail(usage, code: 0)
    default: break
    }
}
guard let workspacePath else { fail(usage, code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

func money(_ value: Decimal) -> String { String(format: "%@%.2f", value < 0 ? "-" : "", abs(NSDecimalNumber(decimal: value).doubleValue)) }
func pct(_ value: Decimal) -> String { String(format: "%.1f%%", NSDecimalNumber(decimal: value * 100).doubleValue) }
func padR(_ text: String, _ width: Int) -> String { text.count >= width ? text : text + String(repeating: " ", count: width - text.count) }
func padL(_ text: String, _ width: Int) -> String { text.count >= width ? text : String(repeating: " ", count: width - text.count) + text }

let context = try WorkspaceParser().parse(workspaceURL: root)
let settings = (try? SettingsStore().read(workspaceURL: root)) ?? .defaults()
let taxYear = taxYearArg ?? settings.taxYear
let projection = TaxEngine().project(context, taxYear: taxYear)

print("Tax overview — tax year \(taxYear)")
print(String(repeating: "─", count: 80))
print(padR("ACCOUNT", 20) + padL("TAXABLE INC", 14) + padL("TAXES PAID", 13)
      + padL("EFF RATE", 10) + padL("DIVIDENDS", 12) + padL("INTEREST", 11))
for acct in projection.accounts {
    let rate = acct.effectiveRate.map { pct($0) } ?? "—"
    print(padR(acct.accountId, 20) + padL(money(acct.ytdTaxableIncome), 14) + padL(money(acct.taxesPaid), 13)
          + padL(rate, 10) + padL(money(acct.dividendIncome), 12) + padL(money(acct.interestIncome), 11))
}
print(String(repeating: "─", count: 80))
let realized = projection.realized
print("Realized gain/loss \(taxYear): short-term \(money(realized.shortTermGainLoss)) · "
      + "long-term \(money(realized.longTermGainLoss)) · total \(money(realized.total)) (\(realized.lots.count) disposals)")

// Deduction summary + tax estimate (US3)
let settingsYear = WorkspaceSettings(filingStatus: settings.filingStatus, taxYear: taxYear,
                                     defaultCurrency: settings.defaultCurrency, timezone: settings.timezone)
let deductions = TaxAdjustmentEngine().deductionSummary(context, settings: settingsYear)
let estimate = TaxAdjustmentEngine().taxEstimate(context, settings: settingsYear)
print(String(repeating: "─", count: 80))
print("Deductions: standard \(money(deductions.standardTotal)) vs itemized "
      + "\(money(deductions.itemizedTotal)) → recommend \(deductions.recommended.rawValue)")
print("  above-the-line \(money(deductions.aboveTheLine)) · Schedule C "
      + "\(money(deductions.scheduleC)) · QBI \(money(deductions.qbiDeduction))")
print("  taxable income after adjustments \(money(deductions.taxableIncomeAfterAdjustments))")
for biz in deductions.businessExpenseByGroup {
    let flag = biz.divergence == 0 ? "" : "  ⚠ divergence \(money(biz.divergence))"
    print("  Schedule C [\(biz.accountGroupId)] claimed \(money(biz.claimed)) vs ledger \(money(biz.ledgerTotal))\(flag)")
}
print("Estimate (\(estimate.source.rawValue)): projected liability \(money(estimate.projectedLiability)) · "
      + "taxes paid \(money(estimate.taxesPaid)) · est. return \(money(estimate.estimatedReturn))")

// Prep checklist (US3)
let prep = TaxPrepEngine().prepSummary(context, settings: settingsYear)
print(String(repeating: "─", count: 80))
print("Prep checklist:")
for item in prep.items {
    let mark = item.state == .complete ? "✓" : (item.state == .incomplete ? "◐" : "✗")
    print("  \(mark) \(padR(item.kind.rawValue, 24)) \(item.state.rawValue) — \(item.detail)")
}

// Safe writes (US3) — preview by default; --apply performs the write.
if seedStandard {
    print(String(repeating: "─", count: 80))
    let exists = context.taxAdjustments.contains { $0.taxYear == taxYear && $0.adjustmentType == .standard }
    if exists {
        print("seed-standard: a standard adjustment already exists for \(taxYear) — nothing to do (idempotent).")
    } else if apply {
        let wrote = try TaxAdjustmentEngine().seedStandardAdjustmentIfMissing(workspaceURL: root, settings: settingsYear)
        print("seed-standard: \(wrote ? "wrote standard adjustment row (backed up + logged)." : "already present.")")
    } else {
        let amount = WorkspaceLayout.standardDeduction(filingStatus: settings.filingStatus.rawValue, taxYear: taxYear)
        print("seed-standard [preview]: would write standard adjustment \(money(amount)) for \(taxYear). Re-run with --apply.")
    }
}
if closeYear {
    print(String(repeating: "─", count: 80))
    if TaxPrepEngine().isYearClosed(workspaceURL: root, year: taxYear) {
        print("close-year: \(taxYear) is already closed (archive present) — read-only.")
    } else if apply {
        let archive = try TaxPrepEngine().archiveYear(workspaceURL: root, year: taxYear)
        print("close-year: archived \(archive.taxYear) → Taxes/archive/\(taxYear)-{tax-adjustments,estimated-payments}.csv")
    } else {
        print("close-year [preview]: would archive \(taxYear) to Taxes/archive/. Re-run with --apply.")
    }
}
