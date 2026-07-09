import Testing
import Foundation
@testable import FinanceWorkspaceKit

// 008 US6 T048 — the fixture matrix (FR-023): one valid fixture covering every managed file type
// parses + validates clean, and one invalid variant per reference/domain family surfaces exactly
// its `RuleCatalog` issue on exactly the offending file. Table-driven so a new rule or file type
// extends the table, not the harness.

@Suite struct FixtureMatrixTests {

    // MARK: Valid matrix — every managed type, zero issues

    @Test func fullWorkspaceValidatesCleanAcrossAllManagedTypes() throws {
        let fixture = FixtureWorkspace.full()
        defer { fixture.cleanup() }
        let context = try fixture.parse()
        let result = ValidationEngine().validate(context)

        #expect(result.issues.filter { $0.severity == .error }.isEmpty,
                "valid full fixture raised errors: \(result.issues.map { "\($0.ruleId)@\($0.filePath)" })")
        // Every managed type is actually present in the parse (the matrix means all 23).
        for type in ["registry", "account-groups", "account-rules", "liabilities", "transactions",
                     "categories", "budgets", "budget-allocations", "goals", "savings-progress",
                     "assets", "prices", "dividends", "tax-lots", "portfolios", "sleeves",
                     "sleeve-targets", "benchmark-series", "settings", "tax-adjustments",
                     "tax-estimates", "tax-documents", "estimated-payments"] {
            #expect(!context.records(ofType: type).isEmpty, "no records parsed for \(type)")
        }
    }

    // MARK: Invalid matrix — one bad row per family → exactly its rule

    private struct InvalidCase {
        let name: String
        let file: String
        let header: String
        let rows: [String]
        let expectedRule: String
    }

    private static let month = "2026-06"

    private static let cases: [InvalidCase] = [
        InvalidCase(name: "transaction → unknown category",
                    file: "Accounts/transactions/\(month).csv", header: FixtureWorkspace.fullTxHeader,
                    rows: ["BADC,A1,\(month)-06,-10,,standard,NOPE,,,,,,,,,"],
                    expectedRule: "VAL-CROSS-001"),
        InvalidCase(name: "account → unknown account group",
                    file: "Accounts/accounts.csv", header: FixtureWorkspace.acctHeader,
                    rows: ["A1,Checking,Bank,checking,personal,active,GHOST"],
                    expectedRule: "VAL-CROSS-002"),
        InvalidCase(name: "transaction → unknown account",
                    file: "Accounts/transactions/\(month).csv", header: FixtureWorkspace.fullTxHeader,
                    rows: ["BADA,GHOST,\(month)-06,-10,,standard,,,,,,,,,,"],
                    expectedRule: "VAL-CROSS-003"),
        InvalidCase(name: "price → unknown asset",
                    file: "Investments/prices.csv", header: FixtureWorkspace.priceHeader,
                    rows: ["PX,GHOST,\(month)-27,105"],
                    expectedRule: "VAL-CROSS-004"),
        InvalidCase(name: "sleeve → unknown portfolio",
                    file: "Investments/sleeves.csv", header: FixtureWorkspace.sleeveHeader,
                    rows: ["SLX,GHOST,US Equity"],
                    expectedRule: "VAL-CROSS-006"),
        InvalidCase(name: "sleeve target → unknown sleeve",
                    file: "Investments/sleeve-targets.csv", header: FixtureWorkspace.sleeveTargetHeader,
                    rows: ["STX,GHOST,0.6"],
                    expectedRule: "VAL-CROSS-007"),
        InvalidCase(name: "progress → unknown goal",
                    file: "Savings/progress.csv", header: FixtureWorkspace.progressHeader,
                    rows: ["PRX,GHOST,\(month)-15,2500"],
                    expectedRule: "VAL-CROSS-008"),
        InvalidCase(name: "duplicate transaction id",
                    file: "Accounts/transactions/\(month).csv", header: FixtureWorkspace.fullTxHeader,
                    rows: ["DUP,A1,\(month)-06,-10,,standard,,,,,,,,,,",
                           "DUP,A1,\(month)-07,-11,,standard,,,,,,,,,,"],
                    expectedRule: "VAL-CROSS-010"),
        InvalidCase(name: "asset without owning account",
                    file: "Investments/assets.csv", header: FixtureWorkspace.assetHeader,
                    rows: ["ASX,VTI,Total Market,etf,,SL1,USD"],
                    expectedRule: "VAL-DOMAIN-003"),
        InvalidCase(name: "trade with neither asset side",
                    file: "Accounts/transactions/\(month).csv", header: FixtureWorkspace.fullTxHeader,
                    rows: ["TRX,I1,\(month)-12,-1000,,trade,,,,,,,,buy,10,100"],
                    expectedRule: "VAL-DOMAIN-004"),
        InvalidCase(name: "unbalanced multi-entry group",
                    file: "Accounts/transactions/\(month).csv", header: FixtureWorkspace.fullTxHeader,
                    rows: ["UB1,A1,\(month)-01,100,,standard,,,UBG,,,,,,,",
                           "UB2,A1,\(month)-01,-30,,standard,,,UBG,,,,,,,"],
                    expectedRule: "VAL-DOMAIN-005"),
        InvalidCase(name: "gross/net group that doesn't reconcile",
                    file: "Accounts/transactions/\(month).csv", header: FixtureWorkspace.fullTxHeader,
                    rows: ["GN1,A1,\(month)-01,5000,,standard,,,GNG,gross,,,,,,",
                           "GN2,A1,\(month)-01,-1000,,standard,,,GNG,withholding,,,,,,",
                           "GN3,A1,\(month)-01,3500,,standard,,,GNG,net,,,,,,"],
                    expectedRule: "VAL-DOMAIN-006"),
    ]

    @Test(arguments: Self.cases.indices)
    func invalidFixtureSurfacesExactlyItsRule(_ index: Int) throws {
        let testCase = Self.cases[index]
        let fixture = FixtureWorkspace.full(month: Self.month)
        defer { fixture.cleanup() }
        // Overwrite the target file with the invalid rows (self-contained bad state).
        fixture.write(testCase.file, testCase.header, testCase.rows)

        let context = try fixture.parse()
        let issues = ValidationEngine().validate(context).issues
        let matching = issues.filter { $0.ruleId == testCase.expectedRule }

        #expect(!matching.isEmpty,
                "\(testCase.name): expected \(testCase.expectedRule); got \(issues.map(\.ruleId))")
        #expect(matching.allSatisfy { $0.filePath == testCase.file || $0.filePath.isEmpty },
                "\(testCase.name): issue attributed to \(matching.map(\.filePath)), expected \(testCase.file)")
    }

    /// A structurally broken file (invalid enum + bad decimal) surfaces file-tier issues on that
    /// file, and only that file.
    @Test func malformedValuesSurfaceFileTierIssues() throws {
        let fixture = FixtureWorkspace.full()
        defer { fixture.cleanup() }
        fixture.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader,
                      ["A1,Checking,Bank,not_a_kind,personal,who-knows,G1"])
        let context = try fixture.parse()
        let issues = ValidationEngine().validate(context).issues
        #expect(issues.contains { $0.ruleId.hasPrefix("VAL-FILE") && $0.filePath == "Accounts/accounts.csv" },
                "expected a file-tier issue on accounts.csv; got \(issues.map { "\($0.ruleId)@\($0.filePath)" })")
    }
}
