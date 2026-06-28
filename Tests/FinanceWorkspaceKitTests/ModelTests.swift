import Testing
import Foundation
@testable import FinanceWorkspaceKit

@Suite struct ModelTests {

    @Test func accountIsSingleStructWithOptionalInvestmentMetadata() {
        let plain = Account(accountId: "a1", displayName: "Checking", institution: "Bank",
                            accountGroup: .checking, accountType: "personal", status: .active,
                            accountGroupId: "g1")
        #expect(plain.investment == nil)
        #expect(plain.isActive)

        let invest = Account(accountId: "a2", displayName: "Brokerage", institution: "Inv",
                             accountGroup: .investment, accountType: "taxable", status: .frozen,
                             accountGroupId: "g1",
                             investment: InvestmentMetadata(taxTreatment: "taxable", performanceTracking: true))
        #expect(invest.investment?.taxTreatment == "taxable")
        #expect(!invest.isActive)
    }

    @Test func savingsGoalStatusLimitedToActiveArchived() {
        #expect(Set(SavingsGoalStatus.allCases) == [.active, .archived])
    }

    @Test func sevenSyncStates() {
        #expect(SyncState.allCases.count == 7)
    }

    @Test func manifestRoundTripsThroughJSON() throws {
        let rec = FileRecord(path: "Accounts/accounts.csv", domain: .accounts, subtype: "registry",
                             schemaVersion: 1, hash: "sha256:abc", modifiedAt: Date(timeIntervalSince1970: 1),
                             byteSize: 10, rowCount: 6, lastIndexedAt: Date(timeIntervalSince1970: 2),
                             validationStatus: .unvalidated)
        let manifest = Manifest(appVersion: "1.0.0", workspaceId: "ws",
                                lastIndexedAt: Date(timeIntervalSince1970: 3), files: [rec])
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(Manifest.self, from: data)
        #expect(decoded == manifest)
        #expect(decoded.files.first?.domain == .accounts)
    }

    @Test func transactionSupportsMultiEntryGroup() {
        let txn = UnifiedTransaction(transactionId: "t1", accountId: "a1",
                                     date: Date(timeIntervalSince1970: 0), amount: -100,
                                     type: .transfer, groupId: "grp1", groupRole: .debit)
        #expect(txn.groupId == "grp1")
        #expect(txn.groupRole == .debit)
    }
}
