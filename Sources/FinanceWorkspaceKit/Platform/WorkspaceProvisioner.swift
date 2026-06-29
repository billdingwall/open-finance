import Foundation

// T024 — Idempotent first-run provisioning: create the standard tree + seed files.
// Never overwrites an existing file (FR-004). Shared by the app and the bootstrap-workspace CLI.

public struct WorkspaceProvisioner: Sendable {

    public struct Outcome: Sendable, Equatable {
        public var createdFolders: [String]
        public var createdFiles: [String]
        public var didCreateAnything: Bool { !createdFolders.isEmpty || !createdFiles.isEmpty }
        public init(createdFolders: [String], createdFiles: [String]) {
            self.createdFolders = createdFolders
            self.createdFiles = createdFiles
        }
    }

    public init() {}

    @discardableResult
    public func provision(at workspaceURL: URL,
                          taxYear: Int = WorkspaceLayout.currentTaxYear()) throws -> Outcome {
        let fm = FileManager.default
        var createdFolders: [String] = []
        var createdFiles: [String] = []

        try fm.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

        for folder in WorkspaceLayout.requiredFolders {
            let url = workspaceURL.appendingPathComponent(folder, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                createdFolders.append(folder)
            }
        }

        for (relativePath, content) in WorkspaceLayout.seedFiles(taxYear: taxYear) {
            let url = workspaceURL.appendingPathComponent(relativePath)
            guard !fm.fileExists(atPath: url.path) else { continue }   // idempotent: preserve user edits
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
            createdFiles.append(relativePath)
        }

        // Mirror the bundled canonical schemas into the workspace for transparency/repair.
        // The bundled copy stays authoritative at runtime (CSVSchemaRegistry); this is a readable copy.
        let schemasDir = workspaceURL.appendingPathComponent(".finance-meta/schemas", isDirectory: true)
        if let schemaURLs = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Schemas") {
            for source in schemaURLs {
                let dest = schemasDir.appendingPathComponent(source.lastPathComponent)
                guard !fm.fileExists(atPath: dest.path) else { continue }   // idempotent
                try fm.copyItem(at: source, to: dest)
                createdFiles.append(".finance-meta/schemas/\(source.lastPathComponent)")
            }
        }

        return Outcome(createdFolders: createdFolders, createdFiles: createdFiles)
    }
}
