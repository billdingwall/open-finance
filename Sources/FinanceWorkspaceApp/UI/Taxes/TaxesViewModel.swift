import Foundation
import FinanceWorkspaceKit

// T055 — Taxes presentation mapper (FR-027/028/029). The session tax year re-runs the tax
// engines over the snapshot context (read-only); all figures are ESTIMATES (V1 scope
// boundary) and pass through untouched. Both deduction totals are always surfaced with the
// engine's recommendation flag — never auto-committed (FR-028).

struct TaxesViewModel {
    let projections: WorkspaceProjections

    var defaultYear: Int { projections.settings.taxYear }

    /// Session tax year (clarify Q1); nil = the workspace settings year.
    func year(_ selected: Int?) -> Int { selected ?? defaultYear }

    private func settings(for year: Int) -> WorkspaceSettings {
        var settings = projections.settings
        settings.taxYear = year
        return settings
    }

    // MARK: - Engine projections per (session) year

    func taxProjection(year: Int) -> TaxEngine.Projection {
        year == defaultYear ? projections.tax
                            : TaxEngine().project(projections.context, taxYear: year)
    }

    func deductions(year: Int) -> TaxDeductionSummary {
        year == defaultYear ? projections.deductions
                            : TaxAdjustmentEngine().deductionSummary(projections.context,
                                                                     settings: settings(for: year))
    }

    func estimate(year: Int) -> TaxEstimateProjection {
        year == defaultYear ? projections.taxEstimate
                            : TaxAdjustmentEngine().taxEstimate(projections.context,
                                                                settings: settings(for: year))
    }

    func prep(year: Int) -> TaxPrepSummary {
        year == defaultYear ? projections.prep
                            : TaxPrepEngine().prepSummary(projections.context,
                                                          settings: settings(for: year))
    }

    // MARK: - Current-year sections

    /// Presentation totals across the engine's per-account projections (labeled derived).
    struct Totals {
        var ytdTaxableIncome: Decimal
        var taxesPaid: Decimal
        var dividends: Decimal
        var interest: Decimal
    }

    func totals(_ projection: TaxEngine.Projection) -> Totals {
        Totals(
            ytdTaxableIncome: projection.accounts.reduce(0) { $0 + $1.ytdTaxableIncome },
            taxesPaid: projection.accounts.reduce(0) { $0 + $1.taxesPaid },
            dividends: projection.accounts.reduce(0) { $0 + $1.dividendIncome },
            interest: projection.accounts.reduce(0) { $0 + $1.interestIncome })
    }

    func effectiveRateRows(_ projection: TaxEngine.Projection) -> [TableRowModel] {
        projection.accounts.map { account in
            TableRowModel(id: account.accountId, cells: [
                .text(accountName(account.accountId)),
                .money(account.ytdTaxableIncome),
                .money(account.taxesPaid),
                .money(account.dividendIncome),
                .money(account.interestIncome),
                account.effectiveRate.map { CellValue.number($0, display: Format.percent($0)) }
                    ?? .muted(TypedStateText.notAvailable),
            ])
        }
    }

    func paymentRows(year: Int) -> [EstimatedPayment] {
        projections.context.estimatedPayments
            .filter { $0.taxYear == year }
            .sorted { $0.quarter < $1.quarter }
    }

    func scheduleCLinks(year: Int) -> [ScheduleCLink] {
        LinkingEngine().scheduleCLinks(in: projections.context)
    }

    func accountName(_ accountId: String) -> String {
        projections.accounts.accounts.first { $0.accountId == accountId }?.displayName ?? accountId
    }

    func groupName(_ accountGroupId: String) -> String {
        projections.context.accountGroups.first { $0.accountGroupId == accountGroupId }?.name
            ?? accountGroupId
    }

    // MARK: - Prep checklist (FR-029)

    struct ChecklistItem: Identifiable {
        var item: PrepItem
        var sourcePath: String
        var education: String
        var id: String { item.id }
    }

    func checklist(year: Int) -> [ChecklistItem] {
        prep(year: year).items.map { item in
            ChecklistItem(item: item, sourcePath: sourcePath(item.kind), education: education(item.kind))
        }
    }

    private func sourcePath(_ kind: PrepItem.Kind) -> String {
        switch kind {
        case .w2Income: return "Accounts/transactions/"
        case .form1099: return "Taxes/documents.csv"
        case .estimatedPayments: return "Taxes/estimates.csv"
        case .deductionConfirmations: return "Taxes/tax-adjustments.csv"
        }
    }

    private func education(_ kind: PrepItem.Kind) -> String {
        switch kind {
        case .w2Income:
            return "W-2 wages come from your employer's year-end form; the ledger's paycheck "
                + "gross/withholding legs should reconcile to it."
        case .form1099:
            return "1099s report non-wage income — interest (1099-INT), dividends (1099-DIV), "
                + "and brokerage proceeds (1099-B). File them under Taxes/documents."
        case .estimatedPayments:
            return "Quarterly estimated payments avoid underpayment penalties; the safe-harbor "
                + "target is based on last year's liability."
        case .deductionConfirmations:
            return "Confirm each adjustment row (standard vs itemized, above-the-line, "
                + "Schedule C) before filing; the greater of standard vs itemized is flagged."
        }
    }

    // MARK: - Archive (FR-029, read-only)

    var closedYears: [Int] { projections.closedTaxYears }

    struct ArchiveFile: Identifiable {
        var path: String
        var contents: String
        var id: String { path }
    }

    /// Raw, read-only archive file previews (the parser deliberately skips archive contents;
    /// this is a presentation-only read of the canonical files — never re-derived).
    func archiveFiles(year: Int) -> [ArchiveFile] {
        let archive = projections.workspaceURL.appendingPathComponent("Taxes/archive")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: archive.path) else { return [] }
        return names
            .filter { $0.hasPrefix("\(year)-") && $0.hasSuffix(".csv") }
            .sorted()
            .map { name in
                let url = archive.appendingPathComponent(name)
                let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? "(unreadable)"
                return ArchiveFile(path: "Taxes/archive/\(name)", contents: contents)
            }
    }
}
