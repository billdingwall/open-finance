# PRD Update Plan — Round 2

Source: `docs/_refinement/r2-review.md` (user direction — multi-cloud + file formats)
Target: `docs/product-requirements.md`
Status: Applied 2026-06-09 *(reconstructed retroactively 2026-06-12)*

---

> **Reconstructed retroactively.** Round 2 was applied directly to the PRD on 2026-06-09. This
> plan is written after the fact to match the existing "Round 2 — 2026-06-09" PRD changelog
> entry. It describes the changes that were made, not pending work.

## Summary

Future-proofing pass. v1 scope is unchanged; the changes add V2 scope markers and one
abstraction requirement so iCloud and CSV are not hard-bound.

## Section-by-Section Changes

### Scope — Out of scope for v1

- Added alternative cloud storage providers (Google Drive, Dropbox, local folder) as V2 items.
- Added xlsx and other spreadsheet-format ingestion and export as V2 items.

### §1 Workspace management

- Added a storage-provider abstraction requirement: the workspace layer addresses storage
  through an abstraction, with iCloud as the v1 implementation.

### §11 Export

- Noted that xlsx export is deferred to V2 (CSV and Markdown export remain v1).

## Cascade

| Doc | Plan file |
|---|---|
| `technical-design.md` | `r2-update-technical-design.md` |
| `product-roadmap.md` | — (no roadmap change; V2 scope markers only) |
| `.specify/memory/constitution.md` | — (no principle change) |

## Changelog entry (already present in product-requirements.md)

```
### Round 2 — 2026-06-09
Source: User direction — future-proofing for multi-cloud and additional file formats.

- Added alternative cloud storage providers (Google Drive, Dropbox, local folder) to Out of Scope for v1 as V2 items
- Added xlsx and other spreadsheet format ingestion and export to Out of Scope for v1 as V2 items
- §1 Workspace management: added storage provider abstraction requirement
- §11 Export: noted xlsx export deferred to V2
```
