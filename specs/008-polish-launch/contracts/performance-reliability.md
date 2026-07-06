# Contract: Performance & Reliability (US4)

## Performance budget (FR-013)

Asserted on current Apple Silicon against the 12-month fixture:

| Metric | Threshold |
|---|---|
| cold-launch → first projection | ≤ 2s |
| full re-index | ≤ 5s |
| UI during re-index | interactive, no perceptible stall |
| repair-apply + re-validate | ≤ 5s |

**Measurement harness**: records the two headline timings (launch→first-projection, full re-index)
and emits pass/fail vs the budget; run manually and, where feasible, in CI.

## Projection caching (FR-015)

**`ProjectionStore` ⇄ `ManifestStore`**

- Cache each domain projection keyed by the **source-file content hashes** the manifest already
  computes; on re-index, recompute **only** domains whose input hashes changed.
- Cache invalidation is exact (hash-based), never time-based.

## Responsiveness (FR-014)

- Parse / validate / `ProjectionStore.build` run **off the main actor** (audit the Phase-5 async path).
- `FileWatcherService` events are **debounced** so a burst (e.g. bulk import) triggers one re-index.
- Module views **lazy-load** so cold launch doesn't block on all engines at once.

## Last-known-valid projection (FR-017)

**`AppState` snapshot swap (existing pattern, hardened)**

- During re-index the prior valid projection stays visible; the new snapshot replaces it in **one
  atomic main-actor assignment** — a view never shows a mix of stale + fresh figures.
- A failed re-index keeps the last valid snapshot and surfaces `reindexError` (not "Synced").

## Sparse-data resilience (FR-016)

- Every engine handles missing months / empty files / partially-filled optional columns with a
  **designed empty or partial state** (extends the Phase-3/4 partial-average handling) — never a crash,
  never a blank/zero where a partial figure is meaningful.

**Guarantees**: ≤2s/≤5s on the fixture; no stale/fresh mixing; no crash on sparse input.
