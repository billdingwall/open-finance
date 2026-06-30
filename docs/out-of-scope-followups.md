# Out-of-Scope Follow-ups

Items that were **in a Spec Kit spec's field of view but deliberately skipped or deferred during
implementation** — captured here so nothing falls through the cracks between phases.

> **Last updated**: 2026-06-30 (seeded from specs `002-foundation-architecture` and
> `003-parsing-validation`).

This is distinct from [`docs/project-management.md`](project-management.md), which tracks the
*planned* `[FIX]`/`[DECIDE]` backlog for upcoming phases. This doc tracks the *unplanned residue* of
work already done: the "we shipped the spec, but consciously left X for later" items.

---

## Workflow

- **As each GitHub Spec Kit spec is implemented**, the remaining items that were skipped or
  deferred during that implementation are added here, attributed to their source spec and task.
- **The product manager reviews these follow-ups** and decides on next steps as needed — promote to
  a future spec, fold into a roadmap phase, convert to a `[DECIDE]` in
  [`docs/project-management.md`](project-management.md), or close as won't-do.

### Status legend

| Status | Meaning |
|---|---|
| **Open** | Deferred; awaiting PM review or a target phase to pick it up |
| **Scheduled** | Assigned to a specific upcoming phase/spec (note which) |
| **Resolved** | Implemented in a later spec (note which) or consciously closed |

---

## Open follow-ups

### From spec `002-foundation-architecture` (Phase 1 — merged PR #15)

#### OOS-1 — iCloud ubiquity-container entitlement + code signing
- **Source**: T004 (the one unchecked task of 50; spec shipped 49/50).
- **Skipped because**: the build environment is Command-Line-Tools-only (SwiftPM, no Xcode GUI), so
  there is no app target to attach the `iCloud.<bundle-id>` entitlement or developer-machine code
  signing to. The `ICloudContainerService` code path itself is implemented and compiles; only the
  entitlement/signing is outstanding. In DEBUG everything runs through the local-folder provider.
- **Suggested next step / target phase**: **Phase 5** (Presentation Layer), when the Xcode app
  target is created for UI/packaging/signing. Until then, real iCloud sync cannot be tested (see
  [`docs/test-plans.md`](test-plans.md)).
- **Status**: Open.

### From spec `003-parsing-validation` (Phase 2 — merged PR #16)

#### OOS-2 — `RepairService` deferred repair classes
- **Source**: T030 (marked `[~]` partial — folder/seed-file/header-casing repairs shipped).
- **Skipped because**: three repair behaviors were judged risky or out of layer for Phase 2:
  - **Optional-column injection** — deferred by design: proactively injecting absent optional
    columns would flag otherwise-clean files; needs an "expected columns" notion first.
  - **Blank-field normalization** — not yet implemented.
  - **`WriteGate` sync-gating wiring** (FR-016a) — lives in the provider layer; repair writes are
    not yet gated on per-file sync state.
- **Suggested next step / target phase**: revisit alongside **Phase 6** (Write Flows, Repair &
  Export), where the write/sync-gate path is built out; the "expected columns" notion may inform the
  optional-column repair.
- **Status**: Open.

#### OOS-3 — Phase 2 validation/repair UI design
- **Source**: the Phase 2 **Design Tasks** in [`docs/product-roadmap.md`](product-roadmap.md) and the
  three Phase 2 Design `[DECIDE]`s in [`docs/project-management.md`](project-management.md) —
  validation issue card, repair preview panel, indexing progress state.
- **Skipped because**: spec `003` was the engine/infrastructure layer only; there is no app UI to
  host these surfaces yet. Intended treatments are explored in the static `prototype/` but are not
  committed design specs.
- **Suggested next step / target phase**: **Phase 5** (Presentation Layer), with the rest of the UI
  design work.
- **Status**: Open.

#### OOS-4 — Investment/reinvested-gain retained equity
- **Source**: spec `004-domain-accounts-budget-overview` (FR-001 / clarify A1) — the
  personal-inflow vs **retained-equity** split.
- **Skipped because**: Phase 3 `AccountEngine` is ledger-only and does not read `type = trade`
  rows (FR-009), so it computes only the **business** portion of retained equity. Retained equity from
  reinvested realized gains depends on trade/lot data.
- **Suggested next step / target phase**: **Phase 4** — extend the split in `PortfolioEngine`/
  `TaxEngine` once trades are modeled.
- **Status**: Open.

#### OOS-5 — Sleeve-funding links populated
- **Source**: spec `004` (FR-015) — `LinkingEngine.sleeveLinks`.
- **Skipped because**: the bundled `transactions` schema carries no `sleeve_id`/trade columns in
  Phase 3; the link mechanism (`receiving_asset_id` → `assets.sleeve_id`) is implemented but yields no
  links until investment trades exist.
- **Suggested next step / target phase**: **Phase 4** — alongside `PortfolioEngine` and the unified
  trade ledger.
- **Status**: Open.

#### OOS-6 — Phase 3 module UI design + Overview KPI "estimated rate"
- **Source**: the six Phase-3 **Design** `[DECIDE]`s in
  [`docs/project-management.md`](project-management.md) (Accounts overview, per-account detail, Budget
  overview, Budget history, Overview dashboard, empty states) and the Savings/Investments "estimated
  rate" field.
- **Skipped because**: spec `004` is the engine/model/seed layer only (no SwiftUI); the rate formulas
  are Phase-4 product decisions.
- **Suggested next step / target phase**: **Phase 5** (module UI) and **Phase 4** (rate formulas).
- **Status**: Open.

---

## Resolved / promoted

_None yet._
