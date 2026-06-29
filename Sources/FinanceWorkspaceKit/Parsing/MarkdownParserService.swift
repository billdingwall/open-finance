import Foundation

// T017 — Parse a Markdown note into a typed NoteRecord. v1 is METADATA-ONLY: front matter is
// extracted and typed; the body is preserved as text but NOT rendered. Note type is classified
// from the `type` front-matter field, falling back to the folder path.

public struct MarkdownParserService: Sendable {

    private let coordinator: FileCoordinatorService
    private let frontMatter: FrontMatterParser

    public init(coordinator: FileCoordinatorService = FileCoordinatorService(),
                frontMatter: FrontMatterParser = FrontMatterParser()) {
        self.coordinator = coordinator
        self.frontMatter = frontMatter
    }

    public func parse(fileAt url: URL, relativePath: String) throws -> NoteRecord {
        let text = try coordinator.coordinatedRead(url) { try String(contentsOf: $0, encoding: .utf8) }
        return parse(text: text, relativePath: relativePath)
    }

    /// Pure parse over file text — directly unit-testable without touching disk.
    public func parse(text: String, relativePath: String) -> NoteRecord {
        let (fm, body) = frontMatter.extract(from: text)

        let noteType = fm?["type"]?.stringValue ?? Self.classifyByPath(relativePath)
        let period = fm?["period"]?.stringValue
        let taxYear = fm?["tax_year"]?.intValue

        return NoteRecord(
            noteType: noteType,
            period: period,
            linkedEntityIDs: fm?["entity_ids"]?.listValue ?? fm?["account_group_ids"]?.listValue ?? [],
            linkedAccountIDs: fm?["account_ids"]?.listValue ?? [],
            linkedSleeveIDs: fm?["sleeve_ids"]?.listValue ?? [],
            taxYear: taxYear,
            body: body,
            sourceFile: relativePath,
            frontMatterPresent: fm != nil
        )
    }

    static func classifyByPath(_ relativePath: String) -> String {
        if relativePath == "Workspace.md" { return "workspace" }
        if relativePath.hasPrefix("Notes/monthly/") { return "monthly" }
        if relativePath.hasPrefix("Notes/strategy/") { return "strategy" }
        return "note"
    }
}
