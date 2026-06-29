import Foundation

// T032 — repair-workspace CLI. Implemented in Phase 2 US3 (RepairService: preview/--dry-run +
// backup/--apply, idempotent, repair-log). Stubbed so the package target builds.

FileHandle.standardError.write(Data(
    "repair-workspace: not yet implemented (Phase 2 US3 — RepairService).\n".utf8))
exit(3)
