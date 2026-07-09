import Testing
import Foundation
@testable import FinanceWorkspaceKit

// 008 US6 T049 — end-to-end integration over a temp workspace (FR-023):
//   read     bootstrap (provision) → parse → validate → project
//   write    intent → preview (drift baseline) → backup → atomic apply → re-parse → re-validate,
//            for add / edit / delete / import / multi-entry group
//   repair   seeded auto-repairable damage → plan (dry) → apply (backed up) → re-validate clears
// Every mutation goes through the one WriteService safe-write path — these tests prove the
// composed pipeline, not the units (those live in WriteEngineTests/).

@Suite struct ReadWriteRepairIntegrationTests {

    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fw-integration-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Finance", isDirectory: true)
    }

    private func backups(at root: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(
            atPath: root.appendingPathComponent(".finance-meta/backups").path)) ?? []
    }

    private func apply(_ plan: WritePlan, at root: URL) throws {
        let service = WriteService(workspaceURL: root)
        _ = try service.apply(service.preview(plan), workspaceState: .available, fileStates: [:])
    }

    private func read(_ rel: String, at root: URL) -> String {
        (try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)) ?? ""
    }

    // MARK: Read flow

    @Test func bootstrapParseValidateProject() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let outcome = try WorkspaceProvisioner().provision(at: root)
        #expect(outcome.didCreateAnything)

        let context = try WorkspaceParser().parse(workspaceURL: root)
        #expect(context.accounts.count == 6)          // the locked six-account seed
        let issues = ValidationEngine().validate(context).issues
        #expect(issues.filter { $0.severity == .error }.isEmpty,
                "fresh bootstrap must validate clean: \(issues.map(\.id))")

        let settings = (try? SettingsStore().read(workspaceURL: root)) ?? .defaults()
        let overview = AccountEngine().overview(context, asOf: Date(), settings: settings)
        #expect(!overview.accounts.isEmpty)
    }

    // MARK: Write flows (preview → backup → atomic apply → re-validate)

    @Test func addEditDeleteRoundTripWithBackups() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        _ = try WorkspaceProvisioner().provision(at: root)
        let rel = "Accounts/account-groups.csv"

        // ADD
        var text = read(rel, at: root)
        let addPlan = WritePlanBuilder.add(
            fields: ["account_group_id": "G9", "name": "Integration", "group_type": "custom"],
            to: rel, fileText: text)
        try apply(addPlan, at: root)
        #expect(read(rel, at: root).contains("G9"))
        let backupsAfterAdd = backups(at: root).filter { $0.hasPrefix("account-groups.csv") }
        #expect(!backupsAfterAdd.isEmpty, "add must back the file up first")

        // EDIT
        text = read(rel, at: root)
        let row = try #require(AppStateFreeDataRow.dataRowNumber(of: "G9", in: text))
        let before = try #require(AppStateFreeDataRow.dataLine(in: text, rowRef: row))
        let editPlan = WritePlanBuilder.edit(
            fields: ["account_group_id": "G9", "name": "Renamed", "group_type": "custom"],
            rowRef: row, before: before, in: rel, fileText: text)
        try apply(editPlan, at: root)
        #expect(read(rel, at: root).contains("Renamed"))

        // DELETE
        text = read(rel, at: root)
        let row2 = try #require(AppStateFreeDataRow.dataRowNumber(of: "G9", in: text))
        let before2 = try #require(AppStateFreeDataRow.dataLine(in: text, rowRef: row2))
        try apply(WritePlanBuilder.delete(rowRef: row2, before: before2, in: rel), at: root)
        #expect(!read(rel, at: root).contains("G9"))

        // The whole round-trip left a clean workspace.
        let issues = ValidationEngine().validate(try WorkspaceParser().parse(workspaceURL: root)).issues
        #expect(issues.filter { $0.severity == .error }.isEmpty)
    }

    @Test func importFlowAppendsMonthlyLedgers() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        _ = try WorkspaceProvisioner().provision(at: root)
        let account = try WorkspaceParser().parse(workspaceURL: root).accounts[0].accountId

        let csv = "date,amount,memo\n2026-05-03,-12.34,Coffee\n2026-06-04,-56.78,Books\n"
        var mapping = ImportMapper().autoDetect(sourceColumns: ["date", "amount", "memo"])
        mapping.targetAccountId = account
        let batch = try ImportMapper().buildBatch(csv: csv, mapping: mapping, existingTransactions: [])
        #expect(batch.includedCount == 2)

        let header = ["transaction_id", "account_id", "date", "amount", "description", "type"]
        try apply(ImportMapper().writePlan(from: batch, headerFor: { _ in header }), at: root)

        #expect(read("Accounts/transactions/2026-05.csv", at: root).contains("Coffee"))
        #expect(read("Accounts/transactions/2026-06.csv", at: root).contains("Books"))
        let issues = ValidationEngine().validate(try WorkspaceParser().parse(workspaceURL: root)).issues
        #expect(issues.filter { $0.severity == .error }.isEmpty)
    }

    @Test func multiEntryGroupWritesAndDeletesAtomically() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        _ = try WorkspaceProvisioner().provision(at: root)
        let account = try WorkspaceParser().parse(workspaceURL: root).accounts[0].accountId
        let header = ["transaction_id", "account_id", "date", "amount", "description",
                      "type", "group_id", "group_role"]
        func leg(_ id: String, _ role: MultiEntryLeg.Role, _ magnitude: Decimal, _ signed: String) -> MultiEntryLeg {
            MultiEntryLeg(role: role, amount: magnitude, fields: [
                "transaction_id": id, "account_id": account, "date": "2026-06-01",
                "amount": signed, "type": "standard",
            ])
        }
        let plan = try #require(MultiEntry.plan(
            kind: .grossNet, month: "2026-06", groupId: "GRP-I",
            legs: [leg("L1", .gross, 5000, "5000"), leg("L2", .withholding, 1000, "-1000"),
                   leg("L3", .net, 4000, "4000")],
            header: header))
        try apply(plan, at: root)
        let ledger = read("Accounts/transactions/2026-06.csv", at: root)
        #expect(ledger.contains("GRP-I") && ledger.contains("L1") && ledger.contains("L3"))

        // Whole-group delete: every leg leaves together.
        let text = read("Accounts/transactions/2026-06.csv", at: root)
        var rows: [(rowRef: Int, line: String)] = []
        for id in ["L1", "L2", "L3"] {
            let ref = try #require(AppStateFreeDataRow.dataRowNumber(of: id, in: text))
            rows.append((ref, try #require(AppStateFreeDataRow.dataLine(in: text, rowRef: ref))))
        }
        try apply(MultiEntry.deletePlan(month: "2026-06", groupRows: rows), at: root)
        #expect(!read("Accounts/transactions/2026-06.csv", at: root).contains("GRP-I"))
    }

    // MARK: Repair flow

    @Test func autoRepairRestoresDamageAndRevalidatesClean() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        _ = try WorkspaceProvisioner().provision(at: root)

        // Damage: remove a required seed file + a required folder.
        try FileManager.default.removeItem(at: root.appendingPathComponent("Budget/categories.csv"))
        try? FileManager.default.removeItem(at: root.appendingPathComponent("Savings"))

        let service = try RepairService()
        let plan = try service.plan(workspaceURL: root)
        #expect(!plan.actions.isEmpty, "damage must be detected as auto-repairable")

        let log = try service.apply(workspaceURL: root)
        #expect(log.contains { $0.result == .applied })
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Budget/categories.csv").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Savings").path))

        // Post-repair the workspace validates clean again (repair → re-validate contract).
        let issues = ValidationEngine().validate(try WorkspaceParser().parse(workspaceURL: root)).issues
        #expect(issues.filter { $0.severity == .error }.isEmpty)
    }
}

/// Row-addressing helpers duplicated from `AppState` (App target — not importable here): the
/// 1-based data-row index skipping `#` comments + the header, and its inverse.
enum AppStateFreeDataRow {
    static func dataLine(in fileText: String, rowRef: Int) -> String? {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var start = 0
        while start < lines.count && lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("#") { start += 1 }
        let index = start + 1 + (rowRef - 1)
        guard index >= 0 && index < lines.count else { return nil }
        return lines[index]
    }

    static func dataRowNumber(of id: String, in fileText: String) -> Int? {
        var lines = fileText.components(separatedBy: "\n")
        if fileText.hasSuffix("\n") { lines.removeLast() }
        var start = 0
        while start < lines.count && lines[start].trimmingCharacters(in: .whitespaces).hasPrefix("#") { start += 1 }
        for (offset, line) in lines.dropFirst(start + 1).enumerated()
        where line.split(separator: ",", omittingEmptySubsequences: false).first.map(String.init) == id {
            return offset + 1
        }
        return nil
    }
}
