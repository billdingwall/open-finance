import Foundation

// T012 — Taxes domain models. The tax module estimates obligations; it is not a computation engine.

public enum TaxAdjustmentType: String, Codable, Sendable, CaseIterable {
    case standard, itemized, credit, liability
    case aboveTheLine = "above_the_line"
    case businessExpense = "business-expense"
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

public struct TaxArchiveYear: Codable, Equatable, Sendable, Identifiable {
    public var taxYear: Int
    public var closedAt: Date
    public var id: Int { taxYear }

    public init(taxYear: Int, closedAt: Date) {
        self.taxYear = taxYear
        self.closedAt = closedAt
    }
}
