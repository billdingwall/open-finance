import Foundation

// Phase 6 (007) US3 (T028) — multi-entry transaction groups (transfers, paycheck gross/net splits,
// principal/interest splits). All legs share a `group_id` and are written/edited/deleted as one
// atomic unit; the group must reconcile before it can be written (FR-017).

public enum MultiEntryKind: Sendable, Equatable {
    case balanced       // double-entry: signed legs net to zero (transfers, principal/interest)
    case grossNet       // net = gross − Σ withholding (paychecks)
}

public struct MultiEntryLeg: Sendable, Equatable {
    public enum Role: String, Sendable { case gross, withholding, net, standard }
    public let role: Role
    public let amount: Decimal          // signed for `.balanced`; magnitude for `.grossNet`
    public var fields: [String: String] // canonical row fields (sans group_id/group_role)
    public init(role: Role, amount: Decimal, fields: [String: String] = [:]) {
        self.role = role; self.amount = amount; self.fields = fields
    }
}

public enum MultiEntry {

    /// Does the group satisfy its reconciliation rule?
    public static func reconciles(kind: MultiEntryKind, legs: [MultiEntryLeg]) -> Bool {
        switch kind {
        case .balanced:
            return legs.reduce(Decimal(0)) { $0 + $1.amount } == 0
        case .grossNet:
            guard let gross = legs.first(where: { $0.role == .gross })?.amount,
                  let net = legs.first(where: { $0.role == .net })?.amount else { return false }
            let withheld = legs.filter { $0.role == .withholding }.reduce(Decimal(0)) { $0 + $1.amount }
            return net == gross - withheld
        }
    }

    /// Build an atomic `WritePlan` that appends every leg (sharing `groupId`) to one monthly ledger.
    /// Returns nil when the group does not reconcile (never emits a partial group).
    public static func plan(kind: MultiEntryKind, month: String, groupId: String,
                            legs: [MultiEntryLeg], header: [String]) -> WritePlan? {
        guard reconciles(kind: kind, legs: legs) else { return nil }
        let diffs = legs.map { leg -> WriteRowDiff in
            var fields = leg.fields
            fields["group_id"] = groupId
            fields["group_role"] = leg.role.rawValue
            let line = CSVRowSerializer.row(fields: fields, header: header)
            return WriteRowDiff(rowRef: nil, kind: .add(after: line), groupId: groupId)
        }
        let path = "Accounts/transactions/\(month).csv"
        return WritePlan(intent: .add, changes: [FileChange(relativePath: path, expectedHash: nil, rowDiffs: diffs)])
    }

    /// Delete every row of a group atomically. `groupRows` are (rowRef, line) pairs sharing the id.
    public static func deletePlan(month: String, groupRows: [(rowRef: Int, line: String)]) -> WritePlan {
        let path = "Accounts/transactions/\(month).csv"
        let diffs = groupRows.map { WriteRowDiff(rowRef: $0.rowRef, kind: .delete(before: $0.line)) }
        return WritePlan(intent: .delete, changes: [FileChange(relativePath: path, expectedHash: nil, rowDiffs: diffs)])
    }
}
