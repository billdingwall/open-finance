# Contract — Shared UI Components (`UI/Shared/` + `DesignSystem/`)

All components consume `DesignSystem` tokens only (no literals) and mirror the `DESIGN.md`
§Components prototype contracts. Every component ships light+dark `#Preview`s and an
empty/degenerate-state rendering.

## DesignSystem (precondition — built first)

- `Tokens.swift`: every front-matter color as `Color` (light/dark via asset-catalog-free dynamic
  `NSColor` mapping or `Color(light:dark:)` helper); radius, spacing scale, row height, sidebar/
  pane/window metrics; shadows/materials.
- `Typography.swift`: page-title / kpi-value / section / panel-title / body / table / overline /
  caption styles; `.monospacedDigit()` on all numeric styles.
- `Components/`: `StatusChipStyle`, `TagStyle`, button styles (primary/secondary/ghost),
  `PanelView` chrome (panel-head + panel-body), filter-pill style.

## Component APIs

| Component | Input | Behavior contract |
|---|---|---|
| `KPICardView` | `KPICardModel` | surface-raised card, overline + 22 px tabular value + delta (pos/neg/flat colors); whole card = tap target → `router.navigate` (FR-008); typedState renders muted designed text |
| `DataTableView` | column specs + `[TableRowModel]` + sort/selection bindings | sticky uppercase header on surface-tint, 30 px rows, numerics right-aligned tabular, hover surface-sunken, selected accent-soft; row select → detail pane `SourceRef` surface (FR-009) |
| `PieChartView` | `[PieSlice]` | Swift Charts `SectorMark` donut; legend + % labels; single-accent-family palette per chart-styling |
| `SparklineView` | `[SparkPoint]` | Swift Charts `LineMark`, short-height (140) wrap, tabular axis labels |
| `BarChartView` | series | Swift Charts `BarMark`; pos/neg coloring for signed values |
| `HeatMapTableView` | `HeatMapModel` | `Grid`-based (D4): sticky row headers, 8 period columns, benchmark comparison row, pos/neg cell color scale + tabular % text; typed "insufficient history" cells muted; row select → traceability (FR-010) |
| `PeriodSelectorView` | `PeriodSelection` binding | month/quarter/year + prev/next; keyboard operable; session-scoped state (FR-011, clarify Q1) |
| `EmptyStateView` | `EmptyStateModel` | glyph + title + one-line message + optional CTA (CTA disabled when write-gated) |
| `LoadingSkeletonView` | shape hint | shimmer placeholders during `phase == .indexing` first load |
| `SourceInspectorView` | `SourceRef` | file path, row number, last-modified, raw field list; "Open in Finder" / "Open in Editor" actions; missing-source state disables both (FR-012) |
| `ValueProvenanceLabel` | `Provenance` | inline imported/derived/repaired/user-edited tag (FR-013) |
| `LedgerTableView` | `[LedgerEntry]` | grouped multi-entry rows with disclosure (D7); legs individually traceable |
| `StatusChip` | kind + count/state | pill, semantic soft-bg variants, leading dot |

## Chart styling (gate)

All chart components are built under the `chart-styling` skill rules: single accent series,
tabular axis labels, pos/neg + heat-map scale, benchmark comparison conventions. No placeholder
SVG/static assets (SC-008).
