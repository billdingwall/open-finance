# Phase 0 Research — Presentation Layer (006)

Consolidated decisions for the plan-level unknowns. Spec-level ambiguities were already resolved in
`/speckit-clarify` (spec §Clarifications, 2026-07-02); everything here is implementation strategy.

---

## D1 — Detail pane implementation: native `.inspector` modifier

**Decision**: Implement `DetailPaneView` with SwiftUI's `.inspector(isPresented:)` (macOS 14+),
hosting a `DetailPaneSurface` enum switch inside; width constrained to the `DESIGN.md` 360–420 px
token via `.inspectorColumnWidth(min:ideal:max:)`.

**Rationale**: `.inspector` is the native macOS trailing slide-over — it gives the
system-standard animation, toolbar integration, and collapse behavior for free, directly
satisfying constitution P-III ("collapsible and closed by default (slide-over, not persistent
split)") and the locked `DESIGN.md` detail-pane contract. A `Bool` + surface enum in `AppState`
keeps it selection-driven and lets ⌘⌥I toggle it.

**Alternatives considered**: (a) `NavigationSplitView` third column — rejected: persistent split
semantics, contradicts the slide-over/closed-by-default lock; (b) custom `ZStack` overlay +
transition — rejected: re-implements native behavior, more code, worse accessibility/keyboard
focus handling.

## D2 — App target packaging: XcodeGen-generated wrapper, unsigned CI build

**Decision**: Check in `App/project.yml` (XcodeGen spec), `App/FinanceWorkspace.entitlements`
(iCloud ubiquity container `iCloud.app.openfinance.FinanceWorkspace`, matching the identifier
already in `AppConfig`), and `App/Info.plist`. The `.xcodeproj` is generated on demand
(`xcodegen generate`) and **not** checked in. CI (`ci-macos.yml`) gains a step:
`brew install xcodegen && xcodegen generate --spec App/project.yml && xcodebuild build
-project App/FinanceWorkspace.xcodeproj -scheme FinanceWorkspace CODE_SIGNING_ALLOWED=NO`.
The app target consumes the local SwiftPM package (all view sources stay in
`Sources/FinanceWorkspaceApp/`); signing + provisioning remain developer-machine actions.

**Rationale**: A `pbxproj` can't be authored or debugged on the CLT-only dev box; XcodeGen's YAML
spec is hand-editable, reviewable, and deterministic, and CI verifies the generated project +
entitlement build (the clarified "in scope, CI-gated" decision). Keeping the project un-checked-in
avoids merge-hostile generated artifacts (regenerable, consistent with P-II's ethos).
`CODE_SIGNING_ALLOWED=NO` verifies compilation + entitlement plumbing without needing signing
secrets in CI.

**Alternatives considered**: (a) hand-authored checked-in `.xcodeproj` — rejected: unmaintainable
without local Xcode, merge conflicts; (b) script-bundled `.app` from the SwiftPM binary +
`codesign` — rejected: bypasses the real target/entitlement path Phase 7 signing needs;
(c) Tuist — rejected: heavier dependency for the same outcome.

## D3 — Projection lifecycle: `ProjectionStore` with atomic snapshot swap

**Decision**: A `ProjectionStore` builds an immutable `WorkspaceProjections` value (parse via
`WorkspaceParser` → run all nine engines + `ValidationEngine` → collect `OverviewDashboard`,
per-module projections, issues) in a background task, then swaps the whole snapshot into
`@Observable` `AppState` in one main-actor assignment. Views read only the current snapshot.
Re-index (menu ⌘R or watcher-triggered later) rebuilds and swaps again; skeletons show while the
first snapshot is pending (`.loading` phase enum).

**Rationale**: Engines are pure `(WorkspaceContext, asOf, settings) → projection` functions —
composing them into one immutable snapshot gives FR-036's "no mixed stale/fresh state" by
construction, keeps the UI responsive (SC-010), and matches technical-design §18 (in-memory,
non-authoritative cache). One snapshot also makes the read-only guarantee trivially testable.

**Alternatives considered**: per-view on-demand engine calls — rejected: repeated parsing,
inconsistent as-of instants across simultaneously visible views, harder loading states.

## D4 — Heat map rendering: Grid-based table on the shared chart color scale

**Decision**: `HeatMapTableView` renders as a SwiftUI `Grid` — sticky first column (account
names + the S&P 500 comparison row), 8 period columns, each cell a rounded rect whose background
comes from the shared pos/neg chart-styling color scale with the % value as tabular text inside;
"insufficient history" renders the typed muted state. `PieChartView`, `SparklineView`, and
`BarChartView` are Swift Charts (`SectorMark`, `LineMark`, `BarMark`).

**Rationale**: The heat map is semantically a *table* (row/column headers, a benchmark comparison
row, text in every cell, row selection for traceability) — `Grid` gives correct text layout,
alignment, keyboard/accessibility semantics, and the sector-performance section reuses it. The
*color scale* is the chart-styling system's pos/neg heat-map scale, so visual language stays
unified. This is the recorded interpretation of FR-010's "heat-map table" for the chart-styling
skill: marks-based charts on Swift Charts; the heat-map **table** on `Grid` + the shared scale.
SC-008 ("no placeholder/static chart assets") is unaffected — nothing is a static asset.

**Alternatives considered**: Swift Charts `RectangleMark` heat map — rejected: axis-label-styled
headers, annotation-based cell text, and a selectable benchmark row fight the framework; cell
text truncation and VoiceOver are worse than native `Grid` rows.

## D5 — Menu command & shortcut matrix (§17)

**Decision** (conflict-checked against system/standard bindings; Phase-6 flows present but
disabled):

| Command | Menu | Shortcut | Phase 5 state |
|---|---|---|---|
| New Workspace | File | ⇧⌘N | enabled (provisioning exists) |
| Open Workspace | File | ⌘O | enabled |
| Reindex Workspace | File | ⌘R | enabled (rebuild snapshot) |
| Validate Workspace | File | ⇧⌘V | enabled (re-run validation) |
| Export Current View | File | ⌘E | **disabled** (Phase 6) |
| Repair Selected Issue | Workspace | ⇧⌘R | **disabled** (preview via issues table only; apply Phase 6) |
| Open Source File | Workspace | ⌘⏎ | enabled (selection context) |
| Reveal in Finder | Workspace | ⇧⌘F… → **⌥⌘R** | enabled |
| Open Backup Folder | Workspace | — (no shortcut) | enabled |
| Toggle Inspector | View | ⌥⌘I | enabled |

**Rationale**: ⇧⌘N/⌘O/⌘E/⌥⌘I follow macOS document-app conventions (⌥⌘I is the standard
inspector toggle, per spec assumption); ⌘R = refresh/reindex mirrors browser/Xcode refresh
muscle memory; Reveal in Finder avoids ⇧⌘F (find) and system-reserved bindings by using ⌥⌘R.
A `Workspace` menu groups workspace-scoped actions per technical-design §17. Final placement is
still checked by the `design-adherence` gate at implementation.

**Alternatives considered**: ⌘N for New Workspace — rejected: reserved for the future "new
transaction/record" primary-object action in Phase 6.

## D6 — State restoration: `userActivity` scene modifier + dictionary codec

**Decision**: `Route` (see data-model.md) serializes to/from a `[String: Any]` user-info payload
(`module`, `entityKind`, `entityID`, plus the detail-pane open flag) through a small
`RouteActivityCodec`; the scene advertises one activity type
(`app.openfinance.navigation`) via `.userActivity(_:)` and restores through
`.onContinueUserActivity(_:)`. Per the clarified decision, only module + entity restore across
relaunch; in-module selector state (period/account/tax-year) is session-only and *not* encoded.

**Rationale**: Matches clarify Q2 (no URL scheme in v1) with the native restoration path; a
dedicated codec keeps the dictionary schema versioned and unit-testable (round-trip test in
`AppRouterTests`).

**Alternatives considered**: `@SceneStorage` per-view — rejected: scatters restoration state and
can't express a typed cross-module route; custom URL scheme — rejected in clarify.

## D7 — Grouped multi-entry ledger rows

**Decision**: `LedgerTableView` groups unified-ledger rows by their `group_id` connector into a
`LedgerEntry` presentation model: one summary row (date, payee/description, net amount, provenance)
with a disclosure control expanding to the constituent legs (gross/withholding/net; principal/
interest), each leg keeping its own source file + row traceability. Ungrouped rows render as
single-leg entries. Grouping is presentation-only, computed from the projection's existing rows.

**Rationale**: FR-020 + the constitution's ledger convention (`group_id` connects multi-entry
transactions) — the data already carries the connector; the UI only folds it. Keeping legs as the
traceable unit preserves P-V (each leg is a real CSV row; the summary row is derived and labeled
as such via `ValueProvenanceLabel`).

**Alternatives considered**: flat rows with a group badge — rejected: fails FR-020's "one grouped
unit"; engine-side grouping — rejected: it's a display concern, and engines are frozen this phase.

## D8 — Test strategy for a view-heavy phase

**Decision**: Unit-test everything below the view body: `AppRouter`/`RouteActivityCodec`
round-trips, `ProjectionStore` (atomic swap; SC-005 read-only guarantee — workspace hash
before/after a full store lifecycle), per-module view models (projection → component contract
mapping incl. typed states), and the menu enable/disable matrix. View *rendering* is covered by
mandatory light+dark `#Preview`s (scaffold skill) and the Milestone-5 manual demo script recorded
in `docs/test-plans.md`. No XCUITest in Phase 5 (needs the Xcode target early and is brittle
pre-polish); it arrives with Phase 7's accessibility/perf audits.

**Rationale**: The view-model seam is where correctness lives (FR-031 forbids logic in views);
testing it in SwiftPM keeps the suite runnable in the existing `swift test` CI job. The manual
demo doubles as the Milestone-5 gate evidence (SC-002).

**Alternatives considered**: snapshot-image testing — rejected: needs third-party deps (none
allowed) and a rendering host; XCUITest now — rejected as above.

---

**All Technical-Context unknowns resolved.** No NEEDS CLARIFICATION remain.
