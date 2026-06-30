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
