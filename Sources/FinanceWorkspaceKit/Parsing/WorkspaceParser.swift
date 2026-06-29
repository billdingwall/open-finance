import Foundation

// T018 — Workspace-wide parse pass. Discovers managed .csv/.md files (excluding .finance-meta/),
// classifies each via the schema registry, parses into typed records, and assembles a
// WorkspaceContext. Resilient per-file: a file that fails to read/parse is recorded as a
// file-level warning and the pass continues (SC-009).

public struct WorkspaceParser: Sendable {

    private let registry: CSVSchemaRegistry
    private let csvParser: CSVParserService
    private let markdownParser: MarkdownParserService

    public init(registry: CSVSchemaRegistry? = nil,
                csvParser: CSVParserService = CSVParserService(),
                markdownParser: MarkdownParserService = MarkdownParserService()) throws {
        self.registry = try registry ?? CSVSchemaRegistry()
        self.csvParser = csvParser
        self.markdownParser = markdownParser
    }

    public func parse(workspaceURL: URL) -> WorkspaceContext {
        var parseResults: [CSVParseResult] = []
        var notes: [NoteRecord] = []

        for relativePath in Self.discover(in: workspaceURL) {
            let url = workspaceURL.appendingPathComponent(relativePath)
            if relativePath.hasSuffix(".csv") {
                guard let schema = registry.schema(forRelativePath: relativePath) else {
                    // Unknown managed file type — recorded at validation time (US2); skip parsing.
                    continue
                }
                do {
                    parseResults.append(try csvParser.parse(fileAt: url, relativePath: relativePath, schema: schema))
                } catch {
                    parseResults.append(CSVParseResult(
                        fileTypeKey: schema.fileTypeKey, filePath: relativePath, records: [],
                        warnings: [.init(file: relativePath, row: nil, column: nil, kind: .malformedRow,
                                         message: "could not read file: \(error)")],
                        schemaVersionFound: nil))
                }
            } else if relativePath.hasSuffix(".md") {
                if let note = try? markdownParser.parse(fileAt: url, relativePath: relativePath) {
                    notes.append(note)
                }
            }
        }

        return WorkspaceContext(workspaceURL: workspaceURL, parseResults: parseResults, notes: notes)
    }

    /// Workspace-relative paths of managed `.csv`/`.md` files, excluding the `.finance-meta/` subtree.
    static func discover(in workspaceURL: URL) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: workspaceURL,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles]) else { return [] }
        let base = workspaceURL.standardizedFileURL.path
        var paths: [String] = []
        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            guard ext == "csv" || ext == "md" else { continue }
            let full = url.standardizedFileURL.path
            guard full.hasPrefix(base) else { continue }
            var relative = String(full.dropFirst(base.count))
            if relative.hasPrefix("/") { relative.removeFirst() }
            guard !relative.hasPrefix(".finance-meta/") else { continue }
            paths.append(relative)
        }
        return paths.sorted()
    }
}
