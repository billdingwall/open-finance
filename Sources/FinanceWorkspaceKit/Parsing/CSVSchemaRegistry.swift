import Foundation

// T013 — Authoritative schema registry. Loads the canonical JSON schemas BUNDLED with the app
// (Bundle.module, clarify Q2) — never the workspace .finance-meta/schemas/ mirror. Classifies a
// workspace-relative path → schema via path → filename, and routes version mismatches to migration.

public struct CSVSchemaRegistry: Sendable {

    public enum RegistryError: Error, CustomStringConvertible {
        case bundleResourcesMissing
        public var description: String {
            switch self {
            case .bundleResourcesMissing: return "bundled Schemas/ resources not found in Bundle.module"
            }
        }
    }

    private let schemasBySubtype: [String: CSVSchema]
    private let schemasByExactFile: [String: CSVSchema]   // keyed by the schema's `file` field

    /// Loads every `*.schema.json` from the bundled `Schemas/` resource directory.
    public init() throws { try self.init(bundle: .module) }

    /// Testable entry point with an explicit bundle.
    init(bundle: Bundle) throws {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Schemas"),
              !urls.isEmpty else {
            throw RegistryError.bundleResourcesMissing
        }
        let decoder = JSONDecoder()
        var bySubtype: [String: CSVSchema] = [:]
        var byFile: [String: CSVSchema] = [:]
        for url in urls {
            let data = try Data(contentsOf: url)
            let schema = try decoder.decode(CSVSchema.self, from: data)
            bySubtype[schema.subtype] = schema
            byFile[schema.file] = schema
        }
        self.schemasBySubtype = bySubtype
        self.schemasByExactFile = byFile
    }

    public var allFileTypeKeys: [String] { Array(schemasBySubtype.keys).sorted() }

    public func schema(forSubtype subtype: String) -> CSVSchema? { schemasBySubtype[subtype] }

    public func currentSchemaVersion(forSubtype subtype: String) -> Int? {
        schemasBySubtype[subtype]?.schemaVersion
    }

    /// Classify a workspace-relative path to its schema (path → filename ordering).
    /// Monthly ledgers `Accounts/transactions/YYYY-MM.csv` map to the `transactions` schema.
    public func schema(forRelativePath relativePath: String) -> CSVSchema? {
        if let exact = schemasByExactFile[relativePath] { return exact }
        if relativePath.hasPrefix("Accounts/transactions/"), relativePath.hasSuffix(".csv") {
            return schemasBySubtype["transactions"]
        }
        return nil
    }
}
