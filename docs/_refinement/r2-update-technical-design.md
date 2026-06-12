# Technical Design Update Plan — Round 2

Source: `docs/_refinement/r2-review.md`, `docs/product-requirements.md` (post Round 2)
Target: `docs/technical-design.md`
Status: Applied 2026-06-09 *(reconstructed retroactively 2026-06-12)*

---

> **Reconstructed retroactively.** Round 2 was applied directly to the technical design on
> 2026-06-09. This plan is written after the fact to match the existing "Round 2 — 2026-06-09"
> technical-design changelog entry. It describes the changes that were made.

## Summary

Introduce the storage-provider abstraction and the xlsx-as-V2 path. No file specs or domain
logic change; the work is at the platform boundary and in scope markers.

## Section-by-Section Changes

### §2 Design goals

- Added storage-provider abstraction as a primary design goal.

### §5 Workspace and iCloud model

- Added a "Storage provider abstraction" subsection defining the `CloudStorageProvider` protocol
  shape and the V2 provider list (Google Drive, Dropbox, local folder).

### §7 File classification rules

- Added an xlsx `UTType` note with a V2 designation and a CSV-boundary conversion strategy
  (spreadsheets convert to canonical CSV at ingest; CSV stays canonical).

### §11 Application architecture — module layout

- Added `CloudStorageProvider.swift` (protocol) to the Platform module layout.
- Annotated `ICloudContainerService` as the v1 conforming implementation.

### §12 Service responsibilities

- Added a `CloudStorageProvider` protocol service entry.
- Updated `WorkspaceManager` and `ICloudContainerService` descriptions to reflect the protocol
  relationship.

### §21 Decisions to lock before build

- Added the `CloudStorageProvider` protocol surface as an open decision (later locked in Round 3).

## Changelog entry (already present in technical-design.md)

```
### Round 2 — 2026-06-09
Source: User direction — future-proofing for multi-cloud and additional file formats.

- §2: Added storage provider abstraction as a primary design goal
- §5: Added "Storage provider abstraction" subsection with `CloudStorageProvider` protocol shape and V2 provider list (Google Drive, Dropbox, local folder)
- §7: Added xlsx UTType note with V2 designation and CSV-boundary conversion strategy
- §11: Added `CloudStorageProvider.swift` (protocol) to Platform module layout; annotated `ICloudContainerService` as v1 conforming implementation
- §12: Added `CloudStorageProvider` protocol service entry; updated `WorkspaceManager` and `ICloudContainerService` descriptions to reflect protocol relationship
- §21: Added `CloudStorageProvider` protocol surface as a new open decision
```
