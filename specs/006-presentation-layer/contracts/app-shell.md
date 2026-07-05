# Contract — App Shell (AppState / AppRouter / header / menu)

## AppState (main-actor, `@Observable`)

- Owns: workspace + provider state (existing), `phase`, `projections` snapshot, `route`,
  `sidebarExpansion`, `detailPane`, `sessionSelections` (see data-model.md).
- Guarantees: `route == .overview` on first ready render (FR-002); snapshot swaps are single
  main-actor assignments (FR-036); no API mutates workspace files (FR-032).

## AppRouter

- `navigate(to: Route)` — updates `route`, syncs sidebar selection + breadcrumb, closes/re-scopes
  the detail pane.
- `route(forKPI: OverviewSummaryCard.ID) -> Route` — KPI tap mapping (FR-015), fixed table:

  | KPI card | Route |
  |---|---|
  | Budget | `.budget(.overview)` |
  | Savings | `.savingsInvestments(.goals)` |
  | Investments | `.savingsInvestments(.portfolio)` |
  | Taxes | `.taxes(.currentYear)` |
  | Business | the business account-group screen (`.accountGroup(id)`) when exactly one business group exists, else `.accounts` |
- `RouteActivityCodec.encode(Route, DetailPaneState) -> [String: AnyHashable]` /
  `decode(_:) -> Route?` — `NSUserActivity` payload, versioned (`v: 1`), activity type
  `app.openfinance.navigation` (D6). Session selectors are **not** encoded (clarify Q1).
- Stale entity IDs on decode fall back to the parent module route.

## Sidebar (`NavigationSidebarView`)

- Header "Finance Dashboard" → `.overview`; **no Overview row** (FR-004).
- Groups: **Account groups** (nested groups → accounts; disabled "New group" action), **Budget**
  (Overview/History/Categories), **Savings & Investments** (Overview/Goals/Portfolio; nested
  goals), **Taxes** (Current Year/Prep Checklist/Archive).
- Active selection = accent-soft bg + accent-ink text (DESIGN token); count badges right-aligned;
  empty groups render the designed empty state; full keyboard traversal (FR-034).

## Global header (`GlobalHeaderView` + `PageTitleActionsView`)

- Issues chip (count from `projections.issues`) immediately **left** of the sync chip (FR-005);
  chips are `StatusChip` pill variants; issues chip tap → `.overview` (issues table).
- Sync chip states: available / indexing(progress) / offline / error, from `phase` + provider
  `syncState` (FR-036).
- Breadcrumb (11 px muted) above the page title for nested routes; local actions right-aligned on
  the page-title line — per-view action set supplied by the active module view (disabled write
  actions included, clarify Q3).

## Detail pane (`DetailPaneView`)

- `.inspector(isPresented:)`, width 360–420 (D1); closed by default; opens on main-panel
  selection; ⌥⌘I toggles; close button in pane header.
- Renders `DetailPaneSurface` (6 cases; `.editForm` unreachable in Phase 5).
- Edit/Delete buttons at pane bottom for entity surfaces — **disabled** (clarify Q3).

## Menu commands (`.commands`, §17 + D5)

| Command | Menu | Shortcut | Enabled | Action |
|---|---|---|---|---|
| New Workspace | File | ⇧⌘N | ✅ | provision flow (existing manager) |
| Open Workspace | File | ⌘O | ✅ | folder picker (DEBUG) / container (release) |
| Reindex Workspace | File | ⌘R | ✅ | `ProjectionStore.rebuild()` |
| Validate Workspace | File | ⇧⌘V | ✅ | re-run validation → refresh issues |
| Export Current View | File | ⌘E | ⛔ Phase 6 | — |
| Repair Selected Issue | Workspace | ⇧⌘R | ⛔ Phase 6 | (preview reachable from issues table) |
| Open Source File | Workspace | ⌘⏎ | ✅ (selection ctx) | default editor via `NSWorkspace` |
| Reveal in Finder | Workspace | ⌥⌘R | ✅ (selection ctx) | `NSWorkspace.activateFileViewerSelecting` |
| Open Backup Folder | Workspace | — | ✅ | reveal `.finance-meta/backups/` |
| Toggle Inspector | View | ⌥⌘I | ✅ | `detailPane.isPresented.toggle()` |

Enable/disable matrix is unit-tested (`CommandMatrixTests`, D8).
