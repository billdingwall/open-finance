import Foundation

// T012 — Taxes domain models. The tax module estimates obligations; it is not a computation engine.

public enum TaxAdjustmentType: String, Codable, Sendable, CaseIterable {
    case standard, credit
    case aboveTheLine = "above_the_line"
    case scheduleA = "schedule_a"      // itemized deductions
    case scheduleC = "schedule_c"      // business expenses
}

public struct TaxAdjustment: Codable, Equatable, Sendable, Identifiable {
    public var taxAdjustmentId: String
    public var adjustmentType: TaxAdjustmentType
    public var amount: Decimal
    public var taxYear: Int
    public var status: String          // estimated | confirmed | not_applicable
    // optional links to a transaction/category/asset/liability/account/account-group
    public var linkedId: String?
    public var id: String { taxAdjustmentId }

    public init(taxAdjustmentId: String, adjustmentType: TaxAdjustmentType, amount: Decimal,
                taxYear: Int, status: String = "estimated", linkedId: String? = nil) {
        self.taxAdjustmentId = taxAdjustmentId
        self.adjustmentType = adjustmentType
        self.amount = amount
        self.taxYear = taxYear
        self.status = status
        self.linkedId = linkedId
    }
}

public struct TaxEstimate: Codable, Equatable, Sendable, Identifiable {
    public var estimateId: String
    public var taxYear: Int
    public var grossIncome: Decimal?
    public var taxesPaid: Decimal?
    public var estimatedReturn: Decimal?     // stored override; nil → engine computes (FR-017)
    public var id: String { estimateId }

    public init(estimateId: String, taxYear: Int, grossIncome: Decimal? = nil,
                taxesPaid: Decimal? = nil, estimatedReturn: Decimal? = nil) {
        self.estimateId = estimateId
        self.taxYear = taxYear
        self.grossIncome = grossIncome
        self.taxesPaid = taxesPaid
        self.estimatedReturn = estimatedReturn
    }
}

public struct TaxDocument: Codable, Equatable, Sendable, Identifiable {
    public var documentId: String
    public var taxYear: Int
    public var kind: String            // e.g. W-2, 1099-INT, 1099-DIV
    public var label: String?
    public var linkedPath: String?
    public var id: String { documentId }

    public init(documentId: String, taxYear: Int, kind: String,
                label: String? = nil, linkedPath: String? = nil) {
        self.documentId = documentId
        self.taxYear = taxYear
        self.kind = kind
        self.label = label
        self.linkedPath = linkedPath
    }
}

public struct EstimatedPayment: Codable, Equatable, Sendable, Identifiable {
    public var paymentId: String
    public var taxYear: Int
    public var quarter: Int            // 1...4
    public var amount: Decimal
    public var paid: Bool
    public var id: String { paymentId }

    public init(paymentId: String, taxYear: Int, quarter: Int, amount: Decimal, paid: Bool = false) {
        self.paymentId = paymentId
        self.taxYear = taxYear
        self.quarter = quarter
        self.amount = amount
        self.paid = paid
    }
}

// MARK: - Tax projection models (US2)

/// Per-account tax read model for the tax year (FR-014/015/016).
public struct AccountTaxProjection: Equatable, Sendable, Identifiable {
    public var accountId: String
    public var ytdTaxableIncome: Decimal
    public var taxesPaid: Decimal              // withholding legs in this account (ledger-derived)
    public var dividendIncome: Decimal
    public var interestIncome: Decimal
    public var effectiveRate: Decimal?         // taxesPaid / gross; nil when gross == 0
    public var id: String { accountId }

    public init(accountId: String, ytdTaxableIncome: Decimal, taxesPaid: Decimal,
                dividendIncome: Decimal, interestIncome: Decimal, effectiveRate: Decimal?) {
        self.accountId = accountId
        self.ytdTaxableIncome = ytdTaxableIncome
        self.taxesPaid = taxesPaid
        self.dividendIncome = dividendIncome
        self.interestIncome = interestIncome
        self.effectiveRate = effectiveRate
    }
}

/// Realized gain/loss for a tax year, split short-term vs long-term (FIFO holding period, FR-016).
public struct RealizedGainSummary: Equatable, Sendable {
    public var taxYear: Int
    public var shortTermGainLoss: Decimal
    public var longTermGainLoss: Decimal
    public var lots: [RealizedDisposal]
    public var total: Decimal { shortTermGainLoss + longTermGainLoss }

    public init(taxYear: Int, shortTermGainLoss: Decimal, longTermGainLoss: Decimal, lots: [RealizedDisposal]) {
        self.taxYear = taxYear
        self.shortTermGainLoss = shortTermGainLoss
        self.longTermGainLoss = longTermGainLoss
        self.lots = lots
    }
}

// MARK: - Deduction / estimate / prep models (US3)

/// Standard-vs-itemized comparison + adjustments; the greater is flagged, never auto-committed (FR-019).
public struct TaxDeductionSummary: Equatable, Sendable {
    public enum Recommendation: String, Equatable, Sendable { case standard, itemized }
    public var taxYear: Int
    public var grossIncome: Decimal
    public var standardTotal: Decimal
    public var itemizedTotal: Decimal
    public var recommended: Recommendation      // the greater — for display only
    public var aboveTheLine: Decimal
    public var scheduleC: Decimal
    public var qbiDeduction: Decimal
    public var taxableIncomeAfterAdjustments: Decimal
    public var businessExpenseByGroup: [BusinessExpenseReconciliation]

    public init(taxYear: Int, grossIncome: Decimal, standardTotal: Decimal, itemizedTotal: Decimal,
                recommended: Recommendation, aboveTheLine: Decimal, scheduleC: Decimal,
                qbiDeduction: Decimal, taxableIncomeAfterAdjustments: Decimal,
                businessExpenseByGroup: [BusinessExpenseReconciliation]) {
        self.taxYear = taxYear
        self.grossIncome = grossIncome
        self.standardTotal = standardTotal
        self.itemizedTotal = itemizedTotal
        self.recommended = recommended
        self.aboveTheLine = aboveTheLine
        self.scheduleC = scheduleC
        self.qbiDeduction = qbiDeduction
        self.taxableIncomeAfterAdjustments = taxableIncomeAfterAdjustments
        self.businessExpenseByGroup = businessExpenseByGroup
    }
}

public struct BusinessExpenseReconciliation: Equatable, Sendable, Identifiable {
    public var accountGroupId: String
    public var claimed: Decimal              // Schedule C business-expense adjustments for the group
    public var ledgerTotal: Decimal          // account-group expense total from the ledger
    public var divergence: Decimal { claimed - ledgerTotal }
    public var id: String { accountGroupId }
    public init(accountGroupId: String, claimed: Decimal, ledgerTotal: Decimal) {
        self.accountGroupId = accountGroupId; self.claimed = claimed; self.ledgerTotal = ledgerTotal
    }
}

/// Computed simplified tax estimate; a non-empty stored `estimates.csv` value overrides (FR-017).
public struct TaxEstimateProjection: Equatable, Sendable {
    public enum Source: String, Equatable, Sendable { case computed, stored }
    public var fiscalYear: Int
    public var taxableIncome: Decimal
    public var projectedLiability: Decimal
    public var taxesPaid: Decimal
    public var estimatedReturn: Decimal       // taxesPaid − projectedLiability (refund if positive)
    public var source: Source

    public init(fiscalYear: Int, taxableIncome: Decimal, projectedLiability: Decimal,
                taxesPaid: Decimal, estimatedReturn: Decimal, source: Source) {
        self.fiscalYear = fiscalYear
        self.taxableIncome = taxableIncome
        self.projectedLiability = projectedLiability
        self.taxesPaid = taxesPaid
        self.estimatedReturn = estimatedReturn
        self.source = source
    }
}

/// Fixed v1 tax-prep checklist (FR-021).
public struct TaxPrepSummary: Equatable, Sendable {
    public var taxYear: Int
    public var items: [PrepItem]
    public init(taxYear: Int, items: [PrepItem]) { self.taxYear = taxYear; self.items = items }
}

public struct PrepItem: Equatable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Sendable, CaseIterable {
        case w2Income = "W-2 income", form1099 = "1099s"
        case estimatedPayments = "Estimated payments", deductionConfirmations = "Deduction confirmations"
    }
    public enum State: String, Equatable, Sendable { case missing, incomplete, complete }
    public var kind: Kind
    public var state: State
    public var detail: String
    public var id: String { kind.rawValue }
    public init(kind: Kind, state: State, detail: String) {
        self.kind = kind; self.state = state; self.detail = detail
    }
}

public struct TaxArchiveYear: Codable, Equatable, Sendable, Identifiable {
    public var taxYear: Int
    public var closedAt: Date
    public var id: Int { taxYear }

    public init(taxYear: Int, closedAt: Date) {
        self.taxYear = taxYear
        self.closedAt = closedAt
    }
}
