# Running & Testing the App (Phase 1)

How to build, run, and test the FinanceWorkspaceApp foundation on your Mac.

> **Status:** Phase 1 (Foundation & Architecture). The app is a **Swift Package**
> (`Package.swift`), not yet an Xcode project. There is no finished UI — Phase 1 is the
> file/workspace foundation, exercised mainly through command-line executables. The iCloud
> path is code-complete but only runs on a signed Mac with the entitlement (see
> [Limitations](#current-limitations)).

## Prerequisites

| Need | For |
|---|---|
| macOS 15 (Sequoia)+ | running anything |
| Swift 6 toolchain (`swift --version`) | `swift build` + running the executables |
| **Full Xcode 16** (not just Command Line Tools) | `swift test` (XCTest / Swift Testing live here) |

Check what you have:

```bash
swift --version          # expect Apple Swift 6.x
xcode-select -p          # /Applications/Xcode.app/... = full Xcode; /Library/Developer/CommandLineTools = CLT only
```

If `xcode-select -p` points at `CommandLineTools`, you can build and run the executables but
**not** `swift test`. Install Xcode and run `sudo xcode-select -s /Applications/Xcode.app` to enable tests.

## 1. Build

```bash
swift build              # debug build of all targets
swift build -c release   # optimized build (faster executables)
```

Expected: `Build complete!`. This compiles the `FinanceWorkspaceKit` library, the app, and
three CLI tools.

## 2. Create a workspace

The workspace is a plain `Finance/` folder of CSV/Markdown files you own. Two ways to make one:

```bash
# Seed a real, valid workspace (six starter accounts, categories, tax settings, Workspace.md)
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance

# Or generate a fuller fixture with N months of sample transactions (good for testing the index)
swift run fixture-generate --workspace ~/Finance-Dev --months 12
```

Both are **idempotent** — re-running never overwrites your edits. Open `~/Finance-Dev/Finance`
in Finder; every file is editable in Numbers/Excel or a text editor. Each CSV starts with a
`# schema_version: 1` comment row.

## 3. Index the workspace

`index-check` scans the workspace, classifies and hashes every file, and prints a summary. It is
the precursor to the in-app indexer and the planned `validate-workspace` script.

```bash
swift run index-check --workspace ~/Finance-Dev/Finance          # scan + print summary
swift run index-check --workspace ~/Finance-Dev/Finance --save   # also persist the manifest
```

Example output:

```
indexed files: 17
by domain: accounts=14, budget=1, meta=1, savings=1
.finance-meta entries (must be 0): 0
error records: 0
Accounts/accounts.csv: rows=6 schema_version=1 hash=sha256:…
manifest saved: ~/Library/Application Support/OpenFinance/finance-main/manifest.json
```

What to confirm:
- **`.finance-meta entries (must be 0)`** — the app-managed `.finance-meta/` subtree is excluded.
- **`error records: 0`** — every file read and hashed cleanly.
- Re-running produces **identical hashes** (the index is deterministic/regenerable).

### Where the manifest lives

The manifest is a **device-local, regenerable cache** — it lives **outside** your synced
workspace, at:

```
~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json
```

Deleting it is safe: the next scan rebuilds it from the files. It is never the source of truth.

## 4. Try the resilient-index behavior

One unreadable file must not break the scan:

```bash
chmod 000 ~/Finance-Dev/Finance/Accounts/transactions/*.csv   # make a file unreadable
swift run index-check --workspace ~/Finance-Dev/Finance        # -> "error records: 1", others still indexed
chmod 644 ~/Finance-Dev/Finance/Accounts/transactions/*.csv   # restore
```

## 5. Run the app (minimal shell)

```bash
swift run FinanceWorkspaceApp
```

In a debug build the app uses the **local-folder provider** (`~/Finance-Dev`) — no iCloud, no
entitlements, no signing. The Phase 1 window is a minimal shell that resolves/provisions the
workspace and shows availability + sync state. (A real macOS app window needs an Xcode app
target; from SwiftPM the shell is primarily for wiring/verification.)

## 6. Run the tests

```bash
swift test               # requires full Xcode (see Prerequisites)
```

Covers provisioning (SC-001/SC-008), file index + exclusion + resilience (FR-007/FR-011a/SC-004),
sync-state mapping + write gate (SC-005), conflict resolution (SC-006), and dual-mode resolution.

If you only have Command Line Tools, `swift test` fails with `no such module 'Testing'`. The tests
still run in **CI** — see `.github/workflows/ci-macos.yml`.

## Current limitations

- **No Xcode app target / iCloud yet.** `ICloudContainerService`, `NSMetadataQuery` sync states, and
  `NSFileVersion` conflict resolution are implemented and compile, but only run on a signed Mac with
  the `iCloud.<bundle-id>` entitlement. In debug builds everything uses the local folder.
- **Tests need full Xcode** (CLT-only machines can build/run but not `swift test`).
- **SwiftLint** runs in CI (Linux); install it locally (`brew install swiftlint`) if you want to lint
  before pushing.

## Quick reference

```bash
swift build                                                   # build
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance
swift run fixture-generate  --workspace ~/Finance-Dev --months 12
swift run index-check       --workspace ~/Finance-Dev/Finance --save
swift run FinanceWorkspaceApp
swift test                                                    # full Xcode only
```
