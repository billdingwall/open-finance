import Testing
import Foundation
@testable import FinanceWorkspaceKit

// T012 / FR-006 / FR-007 / SC-002 — front matter → typed NoteRecord; body preserved (unrendered);
// missing/malformed front matter handled gracefully (flagged, not fatal).

@Suite struct MarkdownParsingTests {

    @Test func frontMatterExtractsTypedMetadataAndPreservesBody() {
        let md = """
        ---
        type: monthly
        period: 2026-05
        account_ids: [acc-1, acc-2]
        tax_year: 2026
        ---

        # May review

        Spending was on track.
        """
        let note = MarkdownParserService().parse(text: md, relativePath: "Notes/monthly/2026-05.md")
        #expect(note.frontMatterPresent)
        #expect(note.noteType == "monthly")
        #expect(note.period == "2026-05")
        #expect(note.linkedAccountIDs == ["acc-1", "acc-2"])
        #expect(note.taxYear == 2026)
        #expect(note.body.contains("Spending was on track."))
        #expect(!note.body.contains("type: monthly"))   // body excludes the front-matter block
    }

    @Test func missingFrontMatterClassifiesByPathAndKeepsBody() {
        let md = "Just a note with no front matter.\n"
        let note = MarkdownParserService().parse(text: md, relativePath: "Notes/strategy/idea.md")
        #expect(note.frontMatterPresent == false)
        #expect(note.noteType == "strategy")            // classified by folder path
        #expect(note.body.contains("Just a note"))
    }

    @Test func unterminatedFrontMatterIsHandledGracefully() {
        let md = "---\ntype: monthly\n(no closing delimiter)\n"
        let (fm, body) = FrontMatterParser().extract(from: md)
        #expect(fm == nil)                               // not fatal — treated as no front matter
        #expect(body == md)
    }

    @Test func workspaceDescriptorClassifiesAsWorkspace() {
        let md = "---\ntype: workspace\nworkspace_id: finance-main\n---\n\nYour workspace.\n"
        let note = MarkdownParserService().parse(text: md, relativePath: "Workspace.md")
        #expect(note.noteType == "workspace")
        #expect(note.frontMatterPresent)
    }
}
