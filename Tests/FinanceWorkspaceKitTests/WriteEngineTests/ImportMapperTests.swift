import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 6 (007) T020 (US2) — column mapping, sign, month-split, duplicate flag.

@Suite struct ImportMapperTests {
    private let csv = """
    Date,Amount,Description
    2026-05-03,-42.50,Coffee
    2026-06-11,1500.00,Paycheck
    2026-06-12,-42.50,Coffee
    """

    @Test func autoDetectMapsDateAndAmount() {
        let m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        #expect(m.map["date"] == "Date")
        #expect(m.map["amount"] == "Amount")
        #expect(m.missingRequired.isEmpty)
    }

    @Test func unmappedRequiredColumnThrows() throws {
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Description"])
        m.targetAccountId = "acct-1"
        #expect(m.missingRequired == ["amount"])
        #expect(throws: ImportError.self) {
            try ImportMapper().buildBatch(csv: csv, mapping: m, existingTransactions: [])
        }
    }

    @Test func rowsSplitByMonthAndStampTargetAccount() throws {
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        m.targetAccountId = "acct-7"
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: m, existingTransactions: [])
        #expect(Set(batch.rowsByMonth.keys) == ["2026-05", "2026-06"])
        #expect(batch.rowsByMonth["2026-06"]?.count == 2)
        #expect(batch.rowsByMonth["2026-05"]?.first?.values["account_id"] == "acct-7")
    }

    @Test func duplicateAgainstExistingIsFlaggedAndExcluded() throws {
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        m.targetAccountId = "acct-7"
        let existing = [ParsedRecord(fields: [
            "account_id": FieldValue(raw: "acct-7", typed: .string("acct-7"), isValid: true),
            "date": FieldValue(raw: "2026-05-03", typed: .string("2026-05-03"), isValid: true),
            "amount": FieldValue(raw: "-42.5", typed: .string("-42.5"), isValid: true),
        ], sourceFile: "Accounts/transactions/2026-05.csv", sourceRow: 1)]
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: m, existingTransactions: existing)
        let mayDup = batch.rowsByMonth["2026-05"]?.first
        #expect(mayDup?.isDuplicate == true)
        #expect(mayDup?.included == false)      // duplicates default excluded (clarify Q2)
    }

    @Test func autoDetectMapsDescriptionSynonyms() {
        #expect(ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Memo"]).map["description"] == "Memo")
        #expect(ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"]).map["description"] == "Description")
    }

    @Test func descriptionRetainedOnMappedRows() throws {
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        m.targetAccountId = "acct-7"
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: m, existingTransactions: [])
        #expect(batch.rowsByMonth["2026-05"]?.first?.values["description"] == "Coffee")
    }

    @Test func differingDescriptionSameDateAmountIsNotDuplicate() throws {
        // Existing row has description "Coffee"; importing "Tea" at the same date+amount is NOT a dup.
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        m.targetAccountId = "acct-7"
        let tea = """
        Date,Amount,Description
        2026-05-03,-42.50,Tea
        """
        let existing = [ParsedRecord(fields: [
            "account_id": FieldValue(raw: "acct-7", typed: .string("acct-7"), isValid: true),
            "date": FieldValue(raw: "2026-05-03", typed: .string("2026-05-03"), isValid: true),
            "amount": FieldValue(raw: "-42.5", typed: .string("-42.5"), isValid: true),
            "description": FieldValue(raw: "Coffee", typed: .string("Coffee"), isValid: true),
        ], sourceFile: "Accounts/transactions/2026-05.csv", sourceRow: 1)]
        let batch = try ImportMapper().buildBatch(csv: tea, mapping: m, existingTransactions: existing)
        #expect(batch.rowsByMonth["2026-05"]?.first?.isDuplicate == false)
    }

    @Test func flippedSignConventionInverts() throws {
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        m.targetAccountId = "acct-7"; m.signConvention = .flipped
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: m, existingTransactions: [])
        // -42.50 flips to positive.
        #expect(batch.rowsByMonth["2026-05"]?.first?.values["amount"]?.hasPrefix("-") == false)
    }

    @Test func writePlanAppendsIncludedRowsPerMonth() throws {
        var m = ImportMapper().autoDetect(sourceColumns: ["Date", "Amount", "Description"])
        m.targetAccountId = "acct-7"
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: m, existingTransactions: [])
        let plan = ImportMapper().writePlan(from: batch) { _ in ["transaction_id", "account_id", "date", "amount", "type"] }
        #expect(plan.intent == .importCSV)
        #expect(plan.changes.count == 2)      // one per month
        #expect(plan.changes.allSatisfy { $0.relativePath.hasPrefix("Accounts/transactions/") })
    }
}
