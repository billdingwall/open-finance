import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T011 / FR-001 — RFC-4180 quoting, leading-`#`/schema_version stripping, and case/whitespace-
// insensitive header mapping.

@Suite struct CSVParserTests {

    // MARK: leading comment stripping

    @Test func stripsLeadingCommentsAndCapturesSchemaVersion() {
        let (body, version) = CSVParserService.stripLeadingComments(
            "# schema_version: 3\n# a note\nheader1,header2\nv1,v2\n")
        #expect(version == 3)
        #expect(body.hasPrefix("header1,header2"))
        #expect(!body.contains("schema_version"))
    }

    @Test func missingSchemaVersionMarkerIsNil() {
        let (_, version) = CSVParserService.stripLeadingComments("a,b\n1,2\n")
        #expect(version == nil)
    }

    // MARK: RFC-4180 tokenizer

    @Test func quotedFieldsPreserveCommasNewlinesAndEscapedQuotes() {
        let rows = CSVParserService.tokenize("a,\"b,c\",d\n\"line1\nline2\",\"say \"\"hi\"\"\"\n")
        #expect(rows.count == 2)
        #expect(rows[0] == ["a", "b,c", "d"])               // embedded comma stays one field
        #expect(rows[1][0] == "line1\nline2")               // embedded newline stays one field
        #expect(rows[1][1] == "say \"hi\"")                 // "" → literal quote
    }

    @Test func handlesCRLFLineEndings() {
        let rows = CSVParserService.tokenize("a,b\r\n1,2\r\n")
        #expect(rows == [["a", "b"], ["1", "2"]])
    }

    // MARK: header mapping

    @Test func headersMapCaseAndWhitespaceInsensitively() throws {
        let schema = try #require(try CSVSchemaRegistry().schema(forSubtype: "registry"))
        let csv = """
        # schema_version: 1
          Account_ID , DISPLAY_NAME ,institution,account_group,account_type,status,account_group_id
        acc-1,My Account,Bank,checking,personal,active,grp-1
        """
        let result = CSVParserService().parse(text: csv, relativePath: "Accounts/accounts.csv", schema: schema)
        #expect(result.schemaVersionFound == 1)
        #expect(result.warnings.isEmpty, "unexpected: \(result.warnings)")
        let row = try #require(result.records.first)
        if case .string(let id)? = row.fields["account_id"]?.typed { #expect(id == "acc-1") }
        else { Issue.record("account_id not mapped from ' Account_ID '") }
        if case .string(let name)? = row.fields["display_name"]?.typed { #expect(name == "My Account") }
        else { Issue.record("display_name not mapped from ' DISPLAY_NAME '") }
    }

    @Test func unknownColumnWarnsButKnownColumnsStillParse() throws {
        let schema = try #require(try CSVSchemaRegistry().schema(forSubtype: "account-groups"))
        let csv = """
        # schema_version: 1
        account_group_id,name,group_type,surprise
        grp-1,Personal,personal,extra
        """
        let result = CSVParserService().parse(text: csv, relativePath: "Accounts/account-groups.csv", schema: schema)
        #expect(result.warnings.contains { $0.kind == .unknownColumn })
        let row = try #require(result.records.first)
        #expect(row.fields["account_group_id"]?.isValid == true)
    }
}
