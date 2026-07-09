import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T040 — Edge-case units for normalization (Decimal/date/int/bool), RFC-4180 tokenizing,
// and front-matter parsing.

@Suite struct NormalizationEdgeTests {

    private func schema() -> CSVSchema {
        CSVSchema(file: "x.csv", domain: "test", subtype: "x", schemaVersion: 1, columns: [
            "amt": ColumnDefinition(type: .decimal, required: true),
            "dt": ColumnDefinition(type: .date, required: true),
            "n": ColumnDefinition(type: .integer, required: false),
            "b": ColumnDefinition(type: .boolean, required: false),
            "e": ColumnDefinition(type: .enumerated, required: false, values: ["red", "green"]),
        ])
    }

    @Test func decimalIsExactAndSignAware() {
        let (rec, warns) = CSVNormalizer().normalize(
            raw: ["amt": "-1234.56", "dt": "2026-05-03"], schema: schema(), file: "f", row: 1)
        #expect(warns.isEmpty)
        #expect(rec.fields["amt"]?.typed == .decimal(Decimal(string: "-1234.56")!))
    }

    @Test func isoDateTimeAndPlainDateBothParse() {
        let plain = CSVNormalizer().normalize(raw: ["amt": "1", "dt": "2026-05-03"], schema: schema(), file: "f", row: 1)
        #expect(plain.record.fields["dt"]?.isValid == true)
        let iso = CSVNormalizer().normalize(raw: ["amt": "1", "dt": "2026-05-03T12:00:00Z"], schema: schema(), file: "f", row: 1)
        #expect(iso.record.fields["dt"]?.isValid == true)
    }

    @Test func invalidIntBoolEnumAreFlagged() {
        let (rec, warns) = CSVNormalizer().normalize(
            raw: ["amt": "1", "dt": "2026-05-03", "n": "x", "b": "maybe", "e": "blue"],
            schema: schema(), file: "f", row: 1)
        #expect(rec.fields["n"]?.isValid == false)
        #expect(rec.fields["b"]?.isValid == false)
        #expect(rec.fields["e"]?.isValid == false)
        #expect(warns.contains { $0.kind == .invalidInteger })
        #expect(warns.contains { $0.kind == .invalidBoolean })
        #expect(warns.contains { $0.kind == .invalidEnum })
    }

    @Test func boolSynonyms() {
        let s = schema()
        for (raw, expected) in [("true", true), ("1", true), ("yes", true), ("false", false), ("0", false), ("no", false)] {
            let r = CSVNormalizer().normalize(raw: ["amt": "1", "dt": "2026-05-03", "b": raw], schema: s, file: "f", row: 1)
            #expect(r.record.fields["b"]?.typed == .boolean(expected))
        }
    }
}

@Suite struct TokenizerEdgeTests {

    @Test func emptyAndTrailingFields() {
        #expect(CSVParserService.tokenize("a,,c\n") == [["a", "", "c"]])
        #expect(CSVParserService.tokenize("a,b,\n") == [["a", "b", ""]])
    }

    @Test func quotedEmptyField() {
        #expect(CSVParserService.tokenize("\"\",x\n") == [["", "x"]])
    }

    @Test func noTrailingNewline() {
        #expect(CSVParserService.tokenize("a,b") == [["a", "b"]])
    }
}

// 008 US4 T038 — sparse-data resilience (FR-017): missing months, empty/header-only files, and
// partially-filled optional columns never crash the pipeline; engines produce sensible
// empty/partial projections. (The last-known-valid-during-reindex half of T038 is App-state
// behavior — see Tests/FinanceWorkspaceAppTests/ReliabilityTests.swift.)

@Suite struct SparseDataResilienceTests {

    private func runAllEngines(_ context: WorkspaceContext, workspaceURL: URL) {
        let settings = (try? SettingsStore().read(workspaceURL: workspaceURL)) ?? .defaults()
        let asOf = Date()
        let accounts = AccountEngine().overview(context, asOf: asOf, settings: settings)
        _ = SavingsGoalEngine().projectGoals(context, asOf: asOf)
        let holdings = PortfolioEngine().holdings(context, asOf: asOf, scope: .aggregate)
        _ = BenchmarkEngine().heatMap(context, asOf: asOf)
        _ = TaxEngine().project(context, taxYear: settings.taxYear)
        _ = TaxAdjustmentEngine().deductionSummary(context, settings: settings)
        let estimate = TaxAdjustmentEngine().taxEstimate(context, settings: settings)
        _ = TaxPrepEngine().prepSummary(context, settings: settings)
        _ = OverviewEngine().dashboard(context, asOf: asOf, settings: settings,
                                       accounts: accounts, aggregateHoldings: holdings,
                                       taxEstimate: estimate)
    }

    @Test func emptyWorkspaceProjectsWithoutCrashing() throws {
        let fixture = FixtureWorkspace()               // folders only, zero files
        defer { fixture.cleanup() }
        let context = try fixture.parse()
        runAllEngines(context, workspaceURL: fixture.root)   // reaching here == no crash
        #expect(context.accounts.isEmpty)
    }

    @Test func headerOnlyFilesProjectAsEmpty() throws {
        let fixture = FixtureWorkspace()
        defer { fixture.cleanup() }
        fixture.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader, [])
        fixture.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, [])
        fixture.write("Budget/categories.csv", FixtureWorkspace.categoryHeader, [])
        fixture.write("Savings/goals.csv", FixtureWorkspace.goalHeader, [])
        fixture.write("Investments/assets.csv", FixtureWorkspace.assetHeader, [])
        let context = try fixture.parse()
        runAllEngines(context, workspaceURL: fixture.root)
        #expect(context.accounts.isEmpty && context.savingsGoals.isEmpty)
    }

    @Test func missingMonthsAreSkippedNotZeroed() throws {
        let fixture = FixtureWorkspace.full(month: "2026-01")
        defer { fixture.cleanup() }
        // A second ledger three months later — Feb/Mar simply don't exist.
        fixture.write("Accounts/transactions/2026-04.csv", FixtureWorkspace.fullTxHeader,
                      ["GAP1,A1,2026-04-02,-50,Groceries,standard,CAT1,,,,,,,,,"])
        let context = try fixture.parse()
        runAllEngines(context, workspaceURL: fixture.root)
        #expect(context.transactions.contains { $0.transactionId == "GAP1" })
    }

    @Test func partialOptionalColumnsAndBadValuesYieldPartialRecords() throws {
        let fixture = FixtureWorkspace.full()
        defer { fixture.cleanup() }
        // A ledger written WITHOUT the optional description/trade columns (pre-008 shape),
        // plus one row with an unparseable amount — parsing flags it, nothing crashes.
        fixture.write("Accounts/transactions/2026-07.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("OLD1", "A1", "2026-07-01", "-25", category: "CAT1"),
            FixtureWorkspace.tx("BAD1", "A1", "2026-07-02", "not-a-number", category: "CAT1"),
        ])
        let context = try fixture.parse()
        runAllEngines(context, workspaceURL: fixture.root)
        #expect(context.transactions.contains { $0.transactionId == "OLD1" })
        // The bad row never becomes a typed transaction with a garbage amount.
        #expect(!context.transactions.contains { $0.transactionId == "BAD1" && $0.amount != 0 })
    }
}

@Suite struct FrontMatterEdgeTests {

    @Test func emptyFrontMatterBlock() {
        let (fm, body) = FrontMatterParser().extract(from: "---\n---\nhello\n")
        #expect(fm != nil)
        #expect(fm?.values.isEmpty == true)
        #expect(body == "hello")
    }

    @Test func listAndScalarValues() {
        let (fm, _) = FrontMatterParser().extract(from: "---\ntags: [a, b, c]\ncount: 3\nflag: true\n---\nx")
        #expect(fm?["tags"]?.listValue == ["a", "b", "c"])
        #expect(fm?["count"]?.intValue == 3)
        #expect(fm?["flag"] == .bool(true))
    }

    @Test func noFrontMatterReturnsFullBody() {
        let (fm, body) = FrontMatterParser().extract(from: "# Heading\ntext\n")
        #expect(fm == nil)
        #expect(body == "# Heading\ntext\n")
    }
}
