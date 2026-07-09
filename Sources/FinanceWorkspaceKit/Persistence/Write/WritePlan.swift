import Foundation

// Phase 6 (007) — the write-engine value types (data-model.md). A `WritePlan` is the previewable,
// atomic unit for every mutation (add/edit/delete/import/repair/year-close). It is applied through
// the Phase-1 safe-write primitives by `WriteService` — never a bespoke per-entity write path.

/// What a plan does — drives logging + UI copy.
public enum WriteIntent: String, Sendable, Equatable {
    case add, edit, delete
    case importCSV = "import"
    case repair
    case closeTaxYear = "close_tax_year"
}

/// One row-level change within a file.
public struct WriteRowDiff: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case add(after: String)                       // append a new row (canonical CSV line)
        case modify(before: String, after: String)    // replace an existing data row
        case delete(before: String)                   // remove an existing data row
    }

    public let rowRef: Int?          // 1-based data-row index (nil for `.add`)
    public let kind: Kind
    public let groupId: String?      // set for multi-entry rows that move together

    public init(rowRef: Int?, kind: Kind, groupId: String? = nil) {
        self.rowRef = rowRef
        self.kind = kind
        self.groupId = groupId
    }
}

/// All row changes targeting a single file, applied atomically.
public struct FileChange: Sendable, Equatable {
    public let relativePath: String       // e.g. "Accounts/transactions/2026-06.csv"
    public let expectedHash: String?      // hash captured at preview (drift check); nil = new file
    public let rowDiffs: [WriteRowDiff]
    /// Canonical header for a file this change may CREATE (e.g. a new monthly ledger): the
    /// writer seeds `# schema_version` + this header before appending rows, so a brand-new file
    /// is never headerless (2026-07-09 fix — caught by the 008 integration tests).
    public let seedHeader: [String]?

    public init(relativePath: String, expectedHash: String?, rowDiffs: [WriteRowDiff],
                seedHeader: [String]? = nil) {
        self.relativePath = relativePath
        self.expectedHash = expectedHash
        self.rowDiffs = rowDiffs
        self.seedHeader = seedHeader
    }
}

/// A group of rows in some collection that reference the object being deleted.
public struct ReferenceGroup: Sendable, Equatable {
    public let collection: String     // referencing collection, e.g. "transactions"
    public let column: String         // FK column, e.g. "category_id"
    public let rows: [RowRef]         // referencing rows
    public let nullable: Bool         // schema-optional → "leave unlinked" allowed
    public let isList: Bool           // list-valued FK (budgets.account_ids/account_group_ids)

    public init(collection: String, column: String, rows: [RowRef],
                nullable: Bool, isList: Bool = false) {
        self.collection = collection
        self.column = column
        self.rows = rows
        self.nullable = nullable
        self.isList = isList
    }
}

/// A referencing row location.
public struct RowRef: Sendable, Equatable {
    public let relativePath: String
    public let rowRef: Int            // 1-based data-row index
    public init(relativePath: String, rowRef: Int) {
        self.relativePath = relativePath
        self.rowRef = rowRef
    }
}

/// The user's chosen resolution for one reference group on a delete.
public struct Reassignment: Sendable, Equatable {
    public enum Target: Sendable, Equatable {
        case reassign(id: String)     // repoint the FK (or replace within a list)
        case unlink                    // clear the FK (nullable) / remove from list
    }
    public let group: ReferenceGroup
    public let target: Target

    public init(group: ReferenceGroup, target: Target) {
        self.group = group
        self.target = target
    }
}

/// Where a backup landed (filled at apply time).
public struct BackupReference: Sendable, Equatable {
    public let relativePath: String
    public let backupName: String     // "<file>.<UTC-timestamp>.bak" under .finance-meta/backups/
    public init(relativePath: String, backupName: String) {
        self.relativePath = relativePath
        self.backupName = backupName
    }
}

/// The previewable, atomic unit for one mutation.
public struct WritePlan: Sendable, Equatable {
    public let intent: WriteIntent
    public var changes: [FileChange]
    public let references: [ReferenceGroup]      // delete only
    public let reassignments: [Reassignment]     // delete only

    public init(intent: WriteIntent, changes: [FileChange],
                references: [ReferenceGroup] = [], reassignments: [Reassignment] = []) {
        self.intent = intent
        self.changes = changes
        self.references = references
        self.reassignments = reassignments
    }

    /// Files this plan touches (deterministic order).
    public var touchedPaths: [String] { changes.map(\.relativePath) }
}

/// Builds single-file `WritePlan`s for structured add/edit/delete (T012). Reference-aware deletes
/// (reassignment) are layered on in US4 via `ReferenceScanner`. Callers pass the current file text so
/// the builder can resolve canonical header order and, for edit/delete, the exact `before` line.
public enum WritePlanBuilder {

    /// Append a new row built from `fields`, ordered by the file's header.
    public static func add(fields: [String: String], to relativePath: String,
                           fileText: String) -> WritePlan {
        let header = CSVRowSerializer.header(of: fileText) ?? Array(fields.keys).sorted()
        let line = CSVRowSerializer.row(fields: fields, header: header)
        return WritePlan(intent: .add, changes: [
            FileChange(relativePath: relativePath, expectedHash: nil,
                       rowDiffs: [WriteRowDiff(rowRef: nil, kind: .add(after: line))],
                       seedHeader: header),
        ])
    }

    /// Replace the data row at `rowRef` (1-based) — current line `before` — with `fields`.
    public static func edit(fields: [String: String], rowRef: Int, before: String,
                            in relativePath: String, fileText: String) -> WritePlan {
        let header = CSVRowSerializer.header(of: fileText) ?? Array(fields.keys).sorted()
        let after = CSVRowSerializer.row(fields: fields, header: header)
        return WritePlan(intent: .edit, changes: [
            FileChange(relativePath: relativePath, expectedHash: nil,
                       rowDiffs: [WriteRowDiff(rowRef: rowRef, kind: .modify(before: before, after: after))]),
        ])
    }

    /// Delete the data row at `rowRef` (1-based) whose current line is `before`.
    public static func delete(rowRef: Int, before: String, in relativePath: String) -> WritePlan {
        WritePlan(intent: .delete, changes: [
            FileChange(relativePath: relativePath, expectedHash: nil,
                       rowDiffs: [WriteRowDiff(rowRef: rowRef, kind: .delete(before: before))]),
        ])
    }
}

/// Result of a successful apply.
public struct WriteResult: Sendable, Equatable {
    public let backups: [BackupReference]
    public let touchedPaths: [String]
    public let logEntries: [String]

    public init(backups: [BackupReference], touchedPaths: [String], logEntries: [String]) {
        self.backups = backups
        self.touchedPaths = touchedPaths
        self.logEntries = logEntries
    }
}

/// Failures surfaced by the write path (each leaves files untouched at the point it is thrown).
public enum WriteError: Error, Sendable, Equatable {
    case syncGateBlocked(path: String, reason: String)  // WriteGate denied (FR-005)
    case driftDetected(path: String)                    // file changed since preview (D8)
    case backupFailed(path: String)                     // could not back up (FR-003)
    case rowRefOutOfRange(path: String, rowRef: Int)    // diff targets a nonexistent row
    case rowMismatch(path: String, rowRef: Int)         // `before` no longer matches the file
}
