# Contract — `CloudStorageProvider`

The storage abstraction the rest of the app depends on instead of calling iCloud directly. v1 ships
two conforming providers; the protocol is the stable seam for V2 backends.

## Protocol surface

```swift
protocol CloudStorageProvider {
    /// Observable; one of the seven sync states (workspace-level).
    var syncState: SyncState { get }
    /// Whether the backend is usable right now (signed in, container reachable, or local folder present).
    var isAvailable: Bool { get }
    /// Resolve the workspace root (…/Documents/Finance for iCloud; ~/Finance-Dev for local).
    func resolveWorkspaceURL() async throws -> URL
    /// Per-file sync state (drives the write gate).
    func syncState(for fileURL: URL) -> FileSyncState
}
```

## Conforming providers

| Provider | When | Resolves to | Sync state source |
|---|---|---|---|
| `ICloudContainerService` | Release/TestFlight (and opt-in dev) | ubiquity container `iCloud.<bundle-id>` → `Documents/Finance` | `NSMetadataQuery` |
| `LocalFolderProvider` | **DEBUG default** | `~/Finance-Dev/` | FSEvents (reports `available`; download/conflict states N/A) |

## `FileSyncState` / `SyncState`

`available · notSignedIn · containerUnavailable · syncing · localCopyStale · fileMissingLocally · conflictDetected`

## Behavioral contract

- `resolveWorkspaceURL()` MUST throw a typed error (not return a nil/empty URL) when the container is
  unavailable or the user is not signed in; the caller surfaces the corresponding sync state.
- `syncState(for:)` MUST reflect downloading/uploading so the write layer can gate (FR-013).
- Conflicts are reported as `conflictDetected`; resolution is performed by the caller via
  `NSFileVersion`, never auto-merged.
- Providers MUST NOT mutate file content; provisioning/writes go through `WorkspaceManager` /
  `FileCoordinatorService`.
