import Foundation

// T037 — migrate-r6 CLI. Implemented in Phase 2 US5 (detect-and-prompt; --dry-run plan / --apply
// atomic renames + ledger fold + reseed + schema_version bump + manifest update). Stubbed so the
// package target builds.

FileHandle.standardError.write(Data(
    "migrate-r6: not yet implemented (Phase 2 US5 — R6 migration).\n".utf8))
exit(3)
