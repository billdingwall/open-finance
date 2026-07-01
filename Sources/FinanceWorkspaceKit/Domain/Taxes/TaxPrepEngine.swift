import Foundation

// US3 (T029-T030) — the fixed v1 tax-prep checklist and the year-close → read-only archive.
// Checklist state is by source-record presence + confirmation; year-close writes archive files whose
// presence marks the year closed (FR-021/022 / research R3/R6).

public struct TaxPrepEngine: Sendable {
    public init() {}

    public enum ArchiveError: Error, Equatable { case alreadyClosed(Int) }

    // MARK: Prep checklist (FR-021)

    public func prepSummary(_ context: WorkspaceContext, settings: WorkspaceSettings) -> TaxPrepSummary {
        let year = settings.taxYear
        let docs = context.taxDocuments.filter { $0.taxYear == year }
        let hasDoc: (String) -> Bool = { needle in docs.contains { $0.kind.uppercased().contains(needle) } }
        let hasIncome = context.transactions.contains {
            PeriodMath.calendarYear($0.date) == year && (($0.type == .standard && $0.amount > 0) || $0.groupRole == .withholding)
        }

        var items: [PrepItem] = []

        // W-2 income
        if hasDoc("W-2") || hasDoc("W2") {
            items.append(PrepItem(kind: .w2Income, state: .complete, detail: "W-2 document on file"))
        } else if hasIncome {
            items.append(PrepItem(kind: .w2Income, state: .incomplete, detail: "income recorded, no W-2 document"))
        } else {
            items.append(PrepItem(kind: .w2Income, state: .missing, detail: "no W-2 document or income"))
        }

        // 1099s
        items.append(PrepItem(kind: .form1099,
                              state: hasDoc("1099") ? .complete : .missing,
                              detail: hasDoc("1099") ? "1099 document on file" : "no 1099 document"))

        // Estimated payments
        let payments = context.estimatedPayments.filter { $0.taxYear == year }
        if payments.isEmpty {
            items.append(PrepItem(kind: .estimatedPayments, state: .missing, detail: "no estimated payments recorded"))
        } else if payments.allSatisfy(\.paid) {
            items.append(PrepItem(kind: .estimatedPayments, state: .complete, detail: "all \(payments.count) payment(s) paid"))
        } else {
            let unpaid = payments.filter { !$0.paid }.count
            items.append(PrepItem(kind: .estimatedPayments, state: .incomplete, detail: "\(unpaid) unpaid payment(s)"))
        }

        // Deduction confirmations
        let adjustments = context.taxAdjustments.filter { $0.taxYear == year }
        if adjustments.isEmpty {
            items.append(PrepItem(kind: .deductionConfirmations, state: .missing, detail: "no adjustments recorded"))
        } else if adjustments.allSatisfy({ $0.status == "confirmed" }) {
            items.append(PrepItem(kind: .deductionConfirmations, state: .complete, detail: "all adjustments confirmed"))
        } else {
            let unconfirmed = adjustments.filter { $0.status != "confirmed" }.count
            items.append(PrepItem(kind: .deductionConfirmations, state: .incomplete, detail: "\(unconfirmed) unconfirmed"))
        }

        return TaxPrepSummary(taxYear: year, items: items)
    }

    // MARK: Year-close archive (FR-022 — safe write, read-only thereafter)

    public func isYearClosed(workspaceURL: URL, year: Int) -> Bool {
        FileManager.default.fileExists(
            atPath: workspaceURL.appendingPathComponent("Taxes/archive/\(year)-tax-adjustments.csv").path)
    }

    @discardableResult
    public func archiveYear(workspaceURL: URL, year: Int) throws -> TaxArchiveYear {
        guard !isYearClosed(workspaceURL: workspaceURL, year: year) else { throw ArchiveError.alreadyClosed(year) }
        let context = try WorkspaceParser().parse(workspaceURL: workspaceURL)

        let adjustments = context.taxAdjustments.filter { $0.taxYear == year }
        let adjHeader = "# schema_version: 1\ntax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id"
        let adjRows = adjustments.map {
            "\($0.taxAdjustmentId),\($0.adjustmentType.rawValue),\(String(format: "%.2f", NSDecimalNumber(decimal: $0.amount).doubleValue)),\($0.taxYear),\($0.status),\($0.linkedId ?? "")"
        }
        try TaxSafeWrite.write(([adjHeader] + adjRows).joined(separator: "\n") + "\n",
                               to: "Taxes/archive/\(year)-tax-adjustments.csv", in: workspaceURL,
                               actionKind: "archiveTaxYear")

        let payments = context.estimatedPayments.filter { $0.taxYear == year }
        let payHeader = "# schema_version: 1\npayment_id,tax_year,quarter,amount,paid"
        let payRows = payments.map {
            "\($0.paymentId),\($0.taxYear),\($0.quarter),\(String(format: "%.2f", NSDecimalNumber(decimal: $0.amount).doubleValue)),\($0.paid)"
        }
        try TaxSafeWrite.write(([payHeader] + payRows).joined(separator: "\n") + "\n",
                               to: "Taxes/archive/\(year)-estimated-payments.csv", in: workspaceURL,
                               actionKind: "archiveTaxYear")

        return TaxArchiveYear(taxYear: year, closedAt: Date())
    }
}
