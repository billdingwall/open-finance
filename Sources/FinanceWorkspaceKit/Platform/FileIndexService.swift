import Foundation
import CryptoKit

// T031/T032/T034 — Recursive discovery + classification + hashing of the finance content tree.
// Excludes the app-managed .finance-meta/ subtree (FR-007). Resilient per-file (FR-011a):
// an unreadable file is recorded with .error and logged; the scan continues. os.Logger diagnostics.

public struct FileIndexService: Sendable {

    public init() {}

    static let indexedExtensions: Set<String> = ["csv", "md"]
    static let excludedDirComponent = ".finance-meta"

    /// Full scan → Manifest. Never throws; per-file failures are isolated.
    public func scan(workspaceRoot: URL, appVersion: String = "1.0.0",
                     workspaceId: String = WorkspaceLayout.workspaceId, now: Date = Date()) -> Manifest {
        let fm = FileManager.default
        let rootPath = workspaceRoot.standardizedFileURL.path
        var records: [FileRecord] = []

        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        let enumerator = fm.enumerator(at: workspaceRoot, includingPropertiesForKeys: keys,
                                       options: [.skipsHiddenFiles])   // also skips .finance-meta
        while let url = enumerator?.nextObject() as? URL {
            // Defensive exclusion in addition to .skipsHiddenFiles.
            if url.pathComponents.contains(Self.excludedDirComponent) { continue }
            guard Self.indexedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isRegular else { continue }

            let relativePath = String(url.standardizedFileURL.path.dropFirst(rootPath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            records.append(indexFile(at: url, relativePath: relativePath, now: now))
        }

        records.sort { $0.path < $1.path }
        return Manifest(appVersion: appVersion, workspaceId: workspaceId, lastIndexedAt: now, files: records)
    }

    /// Index one file. On read/hash failure, returns a record with `.error` status and logs it.
    func indexFile(at url: URL, relativePath: String, now: Date) -> FileRecord {
        let domain = Self.domain(forRelativePath: relativePath)
        let subtype = Self.subtype(forRelativePath: relativePath)
        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now

        do {
            let data = try Data(contentsOf: url)
            let hash = "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let text = String(data: data, encoding: .utf8)
            let schemaVersion = text.flatMap(Self.parseSchemaVersion) ?? 1
            let rowCount = text.map { Self.dataRowCount($0, ext: url.pathExtension.lowercased()) } ?? 0
            return FileRecord(path: relativePath, domain: domain, subtype: subtype,
                              schemaVersion: schemaVersion, hash: hash, modifiedAt: modifiedAt,
                              byteSize: data.count, rowCount: rowCount, lastIndexedAt: now,
                              validationStatus: .unvalidated)
        } catch {
            Diagnostics.index.error("Failed to read/hash \(relativePath, privacy: .public): \(String(describing: error), privacy: .public)")
            return FileRecord(path: relativePath, domain: domain, subtype: subtype,
                              schemaVersion: 0, hash: "", modifiedAt: modifiedAt,
                              byteSize: 0, rowCount: 0, lastIndexedAt: now,
                              validationStatus: .error)
        }
    }

    /// Delta between a prior manifest and a fresh scan (FR-009).
    public func changes(from old: Manifest?, to new: Manifest) -> [FileChangeEvent] {
        let oldByPath = Dictionary(uniqueKeysWithValues: (old?.files ?? []).map { ($0.path, $0) })
        let newByPath = Dictionary(uniqueKeysWithValues: new.files.map { ($0.path, $0) })
        var events: [FileChangeEvent] = []
        for (path, rec) in newByPath {
            if let prior = oldByPath[path] {
                if prior.hash != rec.hash { events.append(.init(kind: .changed, path: path, fileRecord: rec)) }
            } else {
                events.append(.init(kind: .added, path: path, fileRecord: rec))
            }
        }
        for path in oldByPath.keys where newByPath[path] == nil {
            events.append(.init(kind: .deleted, path: path, fileRecord: nil))
        }
        return events.sorted { $0.path < $1.path }
    }

    // MARK: - Classification (folder path → filename)

    static func domain(forRelativePath rel: String) -> FileDomain {
        switch rel.split(separator: "/").first.map(String.init) ?? "" {
        case "Accounts": return .accounts
        case "Budget": return .budget
        case "Savings": return .savings
        case "Investments": return .investments
        case "Taxes": return .taxes
        case "Notes": return .notes
        default: return .meta      // root Workspace.md and any root-level descriptor
        }
    }

    static func subtype(forRelativePath rel: String) -> String {
        let comps = rel.split(separator: "/").map(String.init)
        if comps.count >= 2, comps[comps.count - 2] == "transactions" { return "transactions" }
        return comps.last.map { ($0 as NSString).deletingPathExtension } ?? rel
    }

    static func parseSchemaVersion(_ text: String) -> Int? {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { break }   // only leading comment rows
            if let range = trimmed.range(of: "schema_version:") {
                return Int(trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    /// Data rows = lines excluding leading `#` comments and the header row (CSV only).
    static func dataRowCount(_ text: String, ext: String) -> Int {
        guard ext == "csv" else { return 0 }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        return max(0, lines.count - 1)   // minus header
    }
}
