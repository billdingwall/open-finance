import Foundation

// US3 (T025-T028) — deduction summary (standard-vs-itemized, above-the-line, Schedule C, simplified
// ~20% QBI), computed tax estimate (bracket liability, stored override), business-expense
// cross-reference, and the idempotent standard-adjustment safe write (FR-017/018/019/020 / research R3/R6).

public struct TaxAdjustmentEngine: Sendable {
    public init() {}

    // MARK: Deduction summary (FR-019/020)

    public func deductionSummary(_ context: WorkspaceContext, settings: WorkspaceSettings) -> TaxDeductionSummary {
        let year = settings.taxYear
        let gross = incomeForYear(context, year: year)
        let adjustments = context.taxAdjustments.filter { $0.taxYear == year }

        let standard = WorkspaceLayout.standardDeduction(filingStatus: settings.filingStatus.rawValue, taxYear: year)
        let itemized = adjustments.filter { $0.adjustmentType == .scheduleA }.reduce(Decimal(0)) { $0 + $1.amount }
        let aboveTheLine = adjustments.filter { $0.adjustmentType == .aboveTheLine }.reduce(Decimal(0)) { $0 + $1.amount }
        let scheduleC = adjustments.filter { $0.adjustmentType == .scheduleC }.reduce(Decimal(0)) { $0 + $1.amount }
        let qbi = Decimal(string: "0.20")! * max(0, businessNetIncome(context, year: year))
        let chosen = max(standard, itemized)
        let taxable = max(0, gross - aboveTheLine - scheduleC - qbi - chosen)

        return TaxDeductionSummary(
            taxYear: year, grossIncome: gross, standardTotal: standard, itemizedTotal: itemized,
            recommended: itemized > standard ? .itemized : .standard, aboveTheLine: aboveTheLine, // Recommendation enum, not TaxAdjustmentType
            scheduleC: scheduleC, qbiDeduction: qbi, taxableIncomeAfterAdjustments: taxable,
            businessExpenseByGroup: businessReconciliations(context, adjustments: adjustments, year: year))
    }

    // MARK: Tax estimate (FR-017)

    public func taxEstimate(_ context: WorkspaceContext, settings: WorkspaceSettings) -> TaxEstimateProjection {
        let year = settings.taxYear
        let taxable = deductionSummary(context, settings: settings).taxableIncomeAfterAdjustments
        let liability = bracketLiability(taxable, filingStatus: settings.filingStatus.rawValue, taxYear: year)
        let taxesPaid = taxesPaidForYear(context, year: year)
        let computedReturn = taxesPaid - liability

        // Stored override: a non-empty estimated_return in estimates.csv for the year.
        if let stored = context.taxEstimates.first(where: { $0.taxYear == year && $0.estimatedReturn != nil }),
           let storedReturn = stored.estimatedReturn {
            return TaxEstimateProjection(fiscalYear: year, taxableIncome: taxable, projectedLiability: liability,
                                         taxesPaid: taxesPaid, estimatedReturn: storedReturn, source: .stored)
        }
        return TaxEstimateProjection(fiscalYear: year, taxableIncome: taxable, projectedLiability: liability,
                                     taxesPaid: taxesPaid, estimatedReturn: computedReturn, source: .computed)
    }

    // MARK: Standard-adjustment seed (FR-018 — idempotent safe write)

    /// Seeds a `standard` adjustment row (amount from the deduction table) when none exists for the
    /// tax year. Returns true when a row was written. Idempotent.
    @discardableResult
    public func seedStandardAdjustmentIfMissing(workspaceURL: URL, settings: WorkspaceSettings) throws -> Bool {
        let context = try WorkspaceParser().parse(workspaceURL: workspaceURL)
        let year = settings.taxYear
        let hasStandard = context.taxAdjustments.contains { $0.taxYear == year && $0.adjustmentType == .standard }
        guard !hasStandard else { return false }

        let relative = "Taxes/tax-adjustments.csv"
        let url = workspaceURL.appendingPathComponent(relative)
        let amount = WorkspaceLayout.standardDeduction(filingStatus: settings.filingStatus.rawValue, taxYear: year)
        let row = "adj-standard-\(year),standard,\(String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)),\(year),estimated,"

        let existing: String
        if FileManager.default.fileExists(atPath: url.path) {
            existing = (try? FileCoordinatorService().coordinatedRead(url, { try String(contentsOf: $0, encoding: .utf8) })) ?? ""
        } else {
            existing = "# schema_version: 1\ntax_adjustment_id,adjustment_type,amount,tax_year,status,linked_id\n"
        }
        let newContent = existing.hasSuffix("\n") ? existing + row + "\n" : existing + "\n" + row + "\n"
        try TaxSafeWrite.write(newContent, to: relative, in: workspaceURL, actionKind: "seedStandardAdjustment")
        return true
    }

    // MARK: - Helpers

    private func incomeForYear(_ context: WorkspaceContext, year: Int) -> Decimal {
        context.transactions
            .filter { PeriodMath.calendarYear($0.date) == year && $0.type == .standard
                      && $0.amount > 0 && $0.groupRole != .withholding }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func taxesPaidForYear(_ context: WorkspaceContext, year: Int) -> Decimal {
        let withholding = context.transactions
            .filter { PeriodMath.calendarYear($0.date) == year && $0.groupRole == .withholding }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
        let payments = context.estimatedPayments
            .filter { $0.taxYear == year && $0.paid }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return withholding + payments
    }

    /// Business account-groups' net income (income − expenses) for the year (QBI base).
    private func businessNetIncome(_ context: WorkspaceContext, year: Int) -> Decimal {
        let businessGroupIds = Set(context.accountGroups.filter { $0.groupType == .business }.map(\.accountGroupId))
        let businessAccountIds = Set(context.accounts.filter { businessGroupIds.contains($0.accountGroupId) }.map(\.accountId))
        return netIncome(context, accountIds: businessAccountIds, year: year)
    }

    private func netIncome(_ context: WorkspaceContext, accountIds: Set<String>, year: Int) -> Decimal {
        context.transactions
            .filter { accountIds.contains($0.accountId) && PeriodMath.calendarYear($0.date) == year
                      && $0.type == .standard }
            .reduce(Decimal(0)) { $0 + $1.amount }        // income (+) − expenses (−)
    }

    private func businessReconciliations(_ context: WorkspaceContext, adjustments: [TaxAdjustment],
                                         year: Int) -> [BusinessExpenseReconciliation] {
        let scheduleC = adjustments.filter { $0.adjustmentType == .scheduleC }
        var claimedByGroup: [String: Decimal] = [:]
        for adj in scheduleC { if let g = adj.linkedId { claimedByGroup[g, default: 0] += adj.amount } }
        let accountsByGroup = Dictionary(grouping: context.accounts, by: \.accountGroupId)
        return claimedByGroup.map { groupId, claimed in
            let accountIds = Set((accountsByGroup[groupId] ?? []).map(\.accountId))
            let expenses = context.transactions
                .filter { accountIds.contains($0.accountId) && PeriodMath.calendarYear($0.date) == year
                          && $0.type == .standard && $0.amount < 0 }
                .reduce(Decimal(0)) { $0 + abs($1.amount) }
            return BusinessExpenseReconciliation(accountGroupId: groupId, claimed: claimed, ledgerTotal: expenses)
        }.sorted { $0.accountGroupId < $1.accountGroupId }
    }

    /// Progressive bracket liability from the hardcoded table (simplified estimate).
    private func bracketLiability(_ taxable: Decimal, filingStatus: String, taxYear: Int) -> Decimal {
        guard taxable > 0 else { return 0 }
        var tax: Decimal = 0, lower: Decimal = 0
        for band in WorkspaceLayout.taxBrackets(filingStatus: filingStatus, taxYear: taxYear) {
            let taxableInBand: Decimal
            if let upper = band.upperBound {
                guard taxable > lower else { break }
                taxableInBand = min(taxable, upper) - lower
                tax += taxableInBand * band.rate
                lower = upper
            } else {
                if taxable > lower { tax += (taxable - lower) * band.rate }
                break
            }
        }
        return tax
    }
}
