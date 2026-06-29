import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T010 / FR-004a / SC-009 — a bad field yields a PARTIAL record (field nulled + flagged, row
// retained) plus a warning naming file/row/column. The file never aborts.

@Suite struct NormalizationTests {

    private func transactionsSchema() throws -> CSVSchema {
        let schema = try CSVSchemaRegistry().schema(forSubtype: "transactions")
        return try #require(schema)
    }

    @Test func badFieldsProducePartialRecordsAndWarnings() throws {
        let schema = try transactionsSchema()
        let csv = """
        # schema_version: 1
        transaction_id,account_id,date,amount,type
        txn-1,acc-1,2026-05-03,-42.50,standard
        txn-2,acc-1,NOT-A-DATE,12.00,standard
        txn-3,acc-1,2026-05-04,oops,bogustype
        """
        let result = CSVParserService().parse(text: csv, relativePath: "Accounts/transactions/2026-05.csv",
                                               schema: schema)

        // All three rows retained — bad values do not drop rows (SC-009).
        #expect(result.records.count == 3)

        // Row 1 is fully valid.
        #expect(result.records[0].hasInvalidField == false)
        if case .decimal(let amount)? = result.records[0].fields["amount"]?.typed {
            #expect(amount == Decimal(string: "-42.50"))
        } else { Issue.record("amount did not normalize to a decimal") }

        // Row 2: bad date → that field flagged, others still valid (partial record).
        let row2 = result.records[1]
        #expect(row2.fields["date"]?.isValid == false)
        #expect(row2.fields["date"]?.typed == nil)
        #expect(row2.fields["amount"]?.isValid == true)
        #expect(row2.hasInvalidField == true)

        // Row 3: bad decimal AND bad enum.
        let row3 = result.records[2]
        #expect(row3.fields["amount"]?.isValid == false)
        #expect(row3.fields["type"]?.isValid == false)

        // Warnings name file/row/column and the kind.
        let dateWarning = try #require(result.warnings.first { $0.kind == .invalidDate })
        #expect(dateWarning.file == "Accounts/transactions/2026-05.csv")
        #expect(dateWarning.row == 2)
        #expect(dateWarning.column == "date")
        #expect(result.warnings.contains { $0.kind == .invalidDecimal && $0.row == 3 })
        #expect(result.warnings.contains { $0.kind == .invalidEnum && $0.column == "type" })
    }

    @Test func blankOptionalFieldIsValidNullButBlankRequiredWarns() throws {
        let schema = try transactionsSchema()
        // category_id (optional) blank → valid null; account_id (required) blank → warning.
        let csv = """
        # schema_version: 1
        transaction_id,account_id,date,amount,category_id
        txn-1,,2026-05-03,-1.00,
        """
        let result = CSVParserService().parse(text: csv, relativePath: "Accounts/transactions/2026-05.csv",
                                               schema: schema)
        let row = try #require(result.records.first)
        #expect(row.fields["category_id"]?.isValid == true)          // optional blank = valid null
        #expect(row.fields["category_id"]?.typed == nil)
        #expect(row.fields["account_id"]?.isValid == false)          // required blank = invalid
        #expect(result.warnings.contains { $0.kind == .missingRequiredValue && $0.column == "account_id" })
    }
}
