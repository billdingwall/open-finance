# Out-of-Scope Follow-ups

Items that were **in a Spec Kit spec's field of view but deliberately skipped or deferred during
implementation** — captured here so nothing falls through the cracks between phases.

> **Last updated**: 2026-07-06 (Phase 6 `007-write-flows-repair-export` follow-ups split into their
> own section and renumbered OOS-13…OOS-18 to remove the ID collision with the 006 series; all
> routed to roadmap Phase 8). Earlier: 2026-07-04 (Phase 5 follow-ups added; OOS-1/3/6 → Resolved).

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
- **Status**: **Resolved (partially)** by `006` T060/T061 — see *Resolved / promoted* below;
  signing remains Phase 7.

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
- **Status**: **Resolved (preview scope)** by `006` — see *Resolved / promoted* below.

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
- **Status**: **Resolved** — rate formulas by `005` (Phase 4), module UI by `006` (Phase 5); see
  *Resolved / promoted* below.

---

## Phase 4 (`005-savings-investments-tax`) — deferred during implementation

- **Sector-vs-benchmark comparison** (FR-012): the shipped `benchmarks/sp500.csv` carries only
  `date,close` — no benchmark sector data — so `BenchmarkEngine` reports **portfolio** sector weights
  only, not sector-relative-to-benchmark. *(Source: T034/T035.)* Target: a future schema round adding
  benchmark sector data.
- **Per-account tax allocation**: `TaxEngine` effective rate uses ledger **withholding legs** per
  account; `estimated-payments.csv` (workspace-level, no account link) feeds the tax **estimate**, not
  per-account rates. *(Source: US2/US3.)* Acceptable for v1.
- **Live price ingestion** stays V2 — prices/benchmark come from static CSVs (as planned).
- **Status**: Open.

---

## Phase 5 (`006-presentation-layer`) — deferred during implementation

- **OOS-7 — Itemized tax-archive read model**: the parser deliberately skips `Taxes/archive/`
  (read-only year-close snapshots), so `TaxArchiveView` renders closed years as **raw file
  previews** rather than typed adjustment/payment tables. A typed archive projection would need a
  parser/engine extension. *(Source: 006 T055/T058, FR-029.)* Target: Phase 6 (alongside the
  year-close write flow) or close as won't-do if raw previews suffice. **Status: Open.**
- **OOS-8 — Account estimates surface**: the per-account "Rules & estimates" panel lists
  `account-rules` rows; the separate `AccountEstimate` entity has no `WorkspaceContext` accessor /
  engine projection, so it isn't rendered. *(Source: 006 T041, FR-019.)* Target: Phase 6 with the
  rules/estimates edit flows. **Status: Open.**
- **OOS-9 — `NSUserActivity` restoration end-to-end**: the codec + scene modifiers are implemented
  and unit-tested, but OS-level state restoration is only fully exercisable inside the bundled app
  target (the SwiftPM executable has no `NSUserActivityTypes` registration at runtime). Verify in
  the Xcode-built app during the Phase 7 polish pass. *(Source: 006 T011/T019, research D6.)*
  **Status: Open.**
- **XCUITest automation** deferred to Phase 7 (as planned, research D8); view rendering is covered
  by light/dark previews + the manual Flow 9 demo script in `docs/test-plans.md`.
- **Milestone-5 interactive demo (Flow 9)**: automated proofs passed (boot, SC-005 read-only
  tar-compare, engine⇄view parity tests); the human keyboard/dark-mode/traceability walkthrough is
  recorded as **[Manual pass pending]** in `docs/test-plans.md`. *(Source: 006 T063.)*
  **Status: Open (PM action).**

---

## Phase 6 (`007-write-flows-repair-export`) — deferred during implementation

> IDs renumbered to OOS-13…OOS-18 (2026-07-06) to remove the collision with the 006-series
> OOS-7/8/9 above. **Scheduled into roadmap Phase 7** (`008-polish-launch`, *Complete Phase 6 write
> flows*) — the unfinished spec-`007` write-flow work is finished before launch hardening, not
> deferred to the Phase 8 backlog.

- **OOS-13 — Phase 6 US1 entity forms are schema/header-driven, not per-entity** *(Source: 007 T014;
  deviates from plan research D10)*: US1 ships one `EntityEditForm` that renders a labelled field per
  canonical column of the target file (all 12 row entities editable through the same safe-write path).
  Per-entity typed controls (grouped pickers for account-group/category parents, sign-aware amount
  fields, enum pickers) are the D10 refinement, deferred. **Status: Scheduled — Phase 7 (`008-polish-launch`, *Complete Phase 6 write flows*).**
- **OOS-14 — Account edit uses the shared right-panel path, not dedicated-screen local actions**
  *(Source: 007 T016; FR-010)*: accounts are add/edit/deletable via ⌘N + the detail-pane
  edit/delete buttons like every other entity. The FR-010 placement for a dedicated-screen object
  (edit in the screen's local actions, delete inside the edit flow) on `AccountDetailView` is not yet
  wired. **Status: Scheduled — Phase 7 (`008-polish-launch`, *Complete Phase 6 write flows*).**
- **OOS-15 — transactions schema has no description/merchant column** *(Source: 007 US2; FR-015a)*:
  the canonical `transactions` schema is `transaction_id, account_id, date, amount, type, …` with no
  memo/payee/description field, so imported bank memos are **not retained** and the duplicate key is
  **date + amount + account** (not date+amount+description as the clarified spec assumed). Adding an
  *optional* `description` column (non-breaking per the constitution) is the fix. **Status: Scheduled — Phase 7 (`008-polish-launch`, *Complete Phase 6 write flows*).**
- **OOS-16 — US3 multi-entry transaction editor UI deferred** *(Source: 007 T029/T030)*: the
  reconciliation + atomic group-write/delete **engine** shipped and is unit-tested (`MultiEntry`,
  `MultiEntryWriteTests`), but the `TransactionGroupEditor` SwiftUI view and the ledger group
  edit/delete affordances are not built. Paychecks/transfers cannot yet be authored in-app.
  **Status: Scheduled — Phase 7 (`008-polish-launch`, *Complete Phase 6 write flows*).**
- **OOS-17 — US4 reassignment uses a default target + preview surfacing, not an interactive picker**
  *(Source: 007 T035)*: delete-with-reference **works and never orphans** (scan → expand delete +
  reassignments into one atomic plan, shown in the preview) but the per-collection reassignment
  **picker** (`ReassignmentPickerView`) is not built — the target defaults to the first available id
  (or unlink/remove where nullable/list). User choice of target is the refinement. **Status: Scheduled — Phase 7 (`008-polish-launch`, *Complete Phase 6 write flows*).**
- **OOS-18 — US6 budget Markdown export button not wired** *(Source: 007 T043)*: ⌘E exports the
  active module's primary file as CSV-with-provenance (FR-027); `ExportService.budgetSummaryMarkdown`
  exists and is tested but has no in-view button yet (FR-028). Generic per-table "current view" CSV
  (visible rows of any table) is also simplified to the module's primary file. **Status: Scheduled — Phase 7 (`008-polish-launch`, *Complete Phase 6 write flows*).**

---

## Resolved / promoted

- **OOS-1 — iCloud ubiquity-container entitlement + code signing**: **Resolved (partially) by
  `006-presentation-layer` T060/T061** — the XcodeGen app target (`App/project.yml`) carries the
  container entitlement and builds unsigned in CI; signing/notarization remain developer-machine
  actions until Phase 7.
- **OOS-3 — Phase 2 validation/repair UI design**: **Resolved (preview scope) by
  `006-presentation-layer`** — issue cards/table, issue-detail pane surface, and the dry-run
  repair-preview surface shipped (US3); repair *apply* UI is Phase 6.
- **OOS-6 — Phase 3 module UI design**: **Resolved by `006-presentation-layer`** — all five module
  view groups shipped (US3–US7).
