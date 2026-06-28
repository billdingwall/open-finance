import Testing
import Foundation
@testable import FinanceWorkspaceKit

@Suite struct IndexTests {

    private func provisionedWorkspace() throws -> URL {
        let ws = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-index-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
        try WorkspaceProvisioner().provision(at: ws)
        return ws
    }

    // T027 / FR-007 — scan classifies the finance tree and excludes .finance-meta/.
    @Test func scanClassifiesAndExcludesFinanceMeta() throws {
        let ws = try provisionedWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        // A CSV inside the app-managed subtree must NOT be indexed.
        let logURL = ws.appendingPathComponent(".finance-meta/logs/repair-log.csv")
        try Data("# schema_version: 1\nx\n1\n".utf8).write(to: logURL)

        let manifest = FileIndexService().scan(workspaceRoot: ws)
        #expect(manifest.files.allSatisfy { !$0.path.contains(".finance-meta") })
        // Workspace.md classified under `meta`; accounts.csv under `accounts`.
        #expect(manifest.files.contains { $0.path == "Workspace.md" && $0.domain == .meta })
        #expect(manifest.files.contains { $0.path == "Accounts/accounts.csv" && $0.domain == .accounts })
        // Every indexed file got a hash.
        #expect(manifest.files.allSatisfy { $0.hash.hasPrefix("sha256:") })
    }

    // T028 / SC-004 — deterministic rebuild + ManifestStore round-trip.
    @Test func rebuildIsDeterministicAndManifestRoundTrips() throws {
        let ws = try provisionedWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }

        let svc = FileIndexService()
        let first = svc.scan(workspaceRoot: ws)
        let second = svc.scan(workspaceRoot: ws)

        // Index data (path, hash, size, rowCount) is identical across scans; only timestamps differ.
        func fingerprint(_ m: Manifest) -> [String] {
            m.files.map { "\($0.path)|\($0.hash)|\($0.byteSize)|\($0.rowCount)|\($0.domain.rawValue)" }
        }
        #expect(fingerprint(first) == fingerprint(second))

        // ManifestStore writes to an isolated container and reloads identically.
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-manifest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: container) }
        let store = ManifestStore(containerRoot: container)
        #expect(store.load(workspaceId: first.workspaceId) == nil)   // missing → nil → rebuild
        try store.save(first)
        let reloaded = store.load(workspaceId: first.workspaceId)
        #expect(fingerprint(reloaded!) == fingerprint(first))
    }

    // T028 — change detection emits the right deltas.
    @Test func changeDetectionEmitsDeltas() throws {
        let ws = try provisionedWorkspace()
        defer { try? FileManager.default.removeItem(at: ws.deletingLastPathComponent()) }
        let svc = FileIndexService()
        let base = svc.scan(workspaceRoot: ws)

        // Modify one file, add another.
        try Data("# schema_version: 1\nk,v\nedited,1\n".utf8)
            .write(to: ws.appendingPathComponent("Budget/categories.csv"))
        try Data("# schema_version: 1\nh\nrow\n".utf8)
            .write(to: ws.appendingPathComponent("Notes/monthly/2026-01-review.md"))

        let updated = svc.scan(workspaceRoot: ws)
        let events = svc.changes(from: base, to: updated)
        #expect(events.contains { $0.kind == .changed && $0.path == "Budget/categories.csv" })
        #expect(events.contains { $0.kind == .added && $0.path == "Notes/monthly/2026-01-review.md" })
    }

    // T029 / FR-011a — an unreadable file is isolated, not fatal.
    @Test func unreadableFileIsRecordedAsErrorAndScanContinues() throws {
        let ws = try provisionedWorkspace()
        defer {
            // Restore perms so cleanup can delete it.
            let f = ws.appendingPathComponent("Accounts/accounts.csv")
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: f.path)
            try? FileManager.default.removeItem(at: ws.deletingLastPathComponent())
        }
        let target = ws.appendingPathComponent("Accounts/accounts.csv")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: target.path)

        let manifest = FileIndexService().scan(workspaceRoot: ws)
        let errored = manifest.files.filter { $0.validationStatus == .error }
        #expect(errored.count == 1)
        #expect(errored.first?.path == "Accounts/accounts.csv")
        // Other files still indexed fine.
        #expect(manifest.files.contains { $0.path == "Budget/categories.csv" && $0.validationStatus != .error })
    }
}
