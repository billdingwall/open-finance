# Quickstart — Foundation & Architecture (Phase 1)

How a developer brings up and verifies the foundation. Targets the local-folder dev path (no iCloud
required), then the iCloud path.

## Prerequisites

- macOS 15+, Xcode 16, Swift 6.
- Repo cloned; no Apple developer team required for the local-folder path.

## 1. Environment (Phase 0)

```bash
# Lint + CI config land first
.swiftlint.yml + .github/workflows/swiftlint.yml   # SwiftLint on a Linux runner

# Generate a dev workspace (no iCloud)
swift Scripts/fixture-generate.swift --workspace ~/Finance-Dev --months 12
```

## 2. Run the app (DEBUG → local-folder provider)

- Build & run the `FinanceWorkspaceApp` scheme in DEBUG. `LocalFolderProvider` resolves
  `~/Finance-Dev/Finance` automatically — no entitlement or signing.
- Expected: the app resolves the workspace, indexes it, and persists a manifest at
  `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`.

## 3. Verify the milestone gate

| Check | How | Expected (SC) |
|---|---|---|
| First-run provisioning | Run against an empty folder | Full tree + 6 seed accounts + categories + Workspace.md (SC-001) |
| Scan + hash | Cold launch on the fixture workspace | Completes in a few seconds; manifest lists every file with sha256 + row/byte counts (SC-002) |
| Regenerable index | Delete the manifest, relaunch | Identical index rebuilt from scan; no data loss (SC-004) |
| Incremental re-index | Edit one CSV externally | Only that file re-hashed; a change event fires; others cached (SC-003) |
| Idempotent bootstrap | Re-run bootstrap on a populated workspace | No file duplicated or overwritten (SC-008) |
| Resilient indexing | Drop an unreadable/locked file into the workspace, re-scan | That file gets `error` status + an `os.Logger` entry; all other files index normally; scan does not abort (FR-011a) |
| Index scope | Inspect the manifest | No `.finance-meta/` entries; `Workspace.md` present under the `meta` domain (FR-007); writing a repair/import log does not trigger a re-index |
| Dual-mode resolution | Smoke test | Workspace URL resolves in both iCloud and local-folder modes (SC-007) |

## 4. iCloud path

- Configure the ubiquity-container entitlement with `iCloud.<bundle-id>`; build a non-DEBUG scheme.
- Drive the seven sync states (download a placeholder, go offline, sign out, force a two-device
  conflict) and confirm each is detected/reported and that writes are gated while syncing (SC-005).
- Force a conflict → app offers Keep mine / Keep iCloud / Keep both; neither version is lost (SC-006).

## 5. Tests

```bash
# Unit + fixture-driven integration tests
xcodebuild test -scheme FinanceWorkspaceApp -destination 'platform=macOS'
```

Covers: provider resolution (both modes), bootstrap idempotency, scan/hash correctness, manifest
round-trip + rebuild-from-scratch, incremental delta detection, and the write-gate decision against
each sync state.

## Definition of done (Phase 1 / Milestone 1)

App launches → resolves workspace (both modes) → provisions on first run → scans + hashes → persists
the device-local manifest → detects/exposes the 7 sync states → bootstrap produces a valid scannable
workspace. All core data models defined. Constitution Check passes.
