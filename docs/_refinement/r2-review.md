---
round: 2
date: 2026-06-09
type: user-direction
summary: Future-proofing for multi-cloud storage and additional file formats
status: applied
reconstructed: 2026-06-12
---

> **Reconstructed retroactively on 2026-06-12.** Round 2 was a user-direction revision applied
> directly to the docs on 2026-06-09 without going through the refinement loop at the time.
> This file documents the source direction so the `_refinement/` record lines up with the
> Round 2 changelog entries already present in `product-requirements.md` and `technical-design.md`.
> No new doc edits result from this file.

## Direction

The product should not hard-bind to iCloud or to CSV/Markdown as the only ingestible formats.
Keep v1 scope unchanged (iCloud + CSV/Markdown), but introduce the seams now so multi-cloud and
spreadsheet formats can be added in V2 without a rewrite.

### 1. Storage provider abstraction

* Change description: iCloud should be one implementation behind an abstraction, not the only
  storage path. Other providers (Google Drive, Dropbox, local folder) are V2.
* How to address in product: add a storage-provider abstraction requirement to Workspace
  management; list alternative providers under Out of scope (V2).
* How to address in technical design: introduce a `CloudStorageProvider` protocol; iCloud is the
  v1 conforming implementation; add the V2 provider list and the protocol surface as an open
  decision.

### 2. Additional file formats (xlsx / spreadsheets)

* Change description: CSV stays canonical for v1, but xlsx and other spreadsheet formats should
  be a planned V2 ingestion/export path, converted at the CSV boundary rather than treated as a
  new canonical store.
* How to address in product: add xlsx/spreadsheet ingestion and export to Out of scope (V2);
  note xlsx export deferred to V2 under Export.
* How to address in technical design: add an xlsx `UTType` note with V2 designation and a
  CSV-boundary conversion strategy.

### Roadmap

No roadmap change — these are V2 scope markers, not v1 phase work.
