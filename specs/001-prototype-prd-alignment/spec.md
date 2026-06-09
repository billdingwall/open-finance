# Feature Specification: Prototype as Design Source of Truth

**Feature Branch**: `001-prototype-prd-alignment`
**Created**: 2026-06-08
**Status**: Draft
**Prototype location**: `design/prototype/` (static HTML/CSS/JS)

## Purpose

The prototype at `design/prototype/` is the primary design reference for the v1 macOS
app. Every design decision that affects layout, interaction patterns, information hierarchy, or
visual treatment should be visible and testable here before it is built in Swift.

This spec defines the full scope of what the prototype must cover. It has two parts:

1. **Round 1 alignment** — bring the existing prototype up to date with the interface decisions
   made during the Round 1 design review (navigation restructure, merged modules, updated views).

2. **Phase 1 and Phase 2 design tasks** — add new prototype surfaces for the design work
   identified in `docs/roadmap-v1.md` Phases 1 and 2 that have not yet been designed anywhere.

The prototype should be updated each time new design decisions are made. This spec will be
revised accordingly. When the macOS app is built, the prototype is the reference — not the
other way around.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - App Shell and Navigation Structure (Priority: P1)

A designer or engineer opens the prototype and sees the correct v1 application shell: a three-
column layout with a stable left sidebar, a main content area, and a right inspector panel that
is closed by default. The sidebar shows the correct top-level sections in order. The window
chrome and toolbar show the actions, sync status, and issue indicators that will be present in
the macOS app. The empty navigation state — what a user sees when no section is explicitly selected upon initial load — defaults to the Accounts screen.

**Why this priority**: The shell is the frame for every other design decision. Navigation
structure, column behavior, and the toolbar directly affect how all module views are designed.
This needs to be correct before any module-level review is useful.

**Independent Test**: Open the prototype. Inspect the sidebar top-to-bottom. Inspect the
toolbar. Resize the window to verify minimum usable width. Check that the right panel is
absent on initial load. Confirm the sidebar shows exactly: Overview, Accounts, Budget, Savings
& Investments, Taxes, Settings — nothing else in v1.

**Acceptance Scenarios**:

1. **Given** the prototype is open, **When** a reviewer reads the sidebar, **Then** top-level sections appear in this exact order: Overview, Accounts, Budget, Savings & Investments, Taxes, Settings. Notes, Issues, and Files do not appear.
2. **Given** the Budget section is expanded, **When** the reviewer reads sub-items, **Then** Rules does not appear. Overview, Budget History, and Categories are present.
3. **Given** the Overview section is expanded, **When** the reviewer reads sub-items, **Then** Monthly Snapshots and Annual Snapshots do not appear. Only Dashboard is present.
4. **Given** the Savings & Investments section is expanded, **When** the reviewer reads sub-items, **Then** both Goals (active goals, archived goals) and Portfolio (portfolio overview, accounts, sleeves, holdings, benchmarks) are accessible within one section.
5. **Given** no section is selected, **When** the prototype loads, **Then** the prototype defaults to the Accounts screen, and the right inspector panel is not visible. The main content area fills the full available width (grouped by themes: Personal Assets, Place of Employment, Business Entities).
6. **Given** the reviewer inspects the toolbar, **When** they read left to right, **Then** they can see a workspace identifier, a sync status indicator, and an issue count indicator — the same persistent elements that will appear in the macOS toolbar.

---

### User Story 2 - Right Detail Panel as Slide-Over (Priority: P2)

A reviewer selects a row or KPI card in any module and the right inspector panel appears as a
slide-over from the right edge. The main content does not shift or shrink. The panel closes
when the reviewer clicks outside it or navigates away. The panel is never open by default on
any section or navigation change.

**Why this priority**: This is one of the most significant structural differences between the
current prototype and the PRD spec. The current prototype shows the inspector as a permanent
persistent column. Fixing this establishes the correct interaction model for all module views
and affects how much horizontal space module content can use.

**Independent Test**: Open any module. Confirm the right panel is absent. Select a table row.
Confirm the panel slides in from the right without the content area shifting. Click outside the
panel. Confirm it closes. Navigate to a different section. Confirm the panel remains closed.

**Acceptance Scenarios**:

1. **Given** the prototype loads on any module, **When** no item is selected, **Then** the right panel is not visible and the main content extends to the right edge.
2. **Given** the reviewer selects any table row or KPI card, **When** the selection registers, **Then** the inspector slides in from the right as an overlay — the main content area width does not change.
3. **Given** the inspector is open, **When** the reviewer clicks on an empty area outside it, **Then** the panel closes and the full content area is restored.
4. **Given** the inspector is open, **When** the reviewer clicks on a different item in the main content area, **Then** the panel remains open and its contents update to the new selection.
5. **Given** the inspector is open, **When** the reviewer navigates to a different section, **Then** the panel closes and the selection is cleared.

---

### User Story 3 - First-Launch Onboarding Flow (Priority: P3)

A designer opens the prototype and can walk through a first-launch experience: the app
checks whether iCloud is available, creates or opens the Finance workspace, and guides
the user through any setup steps needed. All seven iCloud availability states are
visually represented so the team can review and decide how each is communicated
to the user.

**Why this priority**: The onboarding and workspace resolution flow is the first thing every
user sees. The seven sync states are defined in the technical design but have never been
designed visually. This work unblocks the Phase 1 development team from having to invent
UI patterns for error states on the fly.

**Independent Test**: Open the prototype and navigate to the onboarding / first-launch section
(this may be a standalone screen or a modal flow overlaid on the shell). Confirm all seven
iCloud states are shown: Available, Not signed in, Container unavailable, Syncing, Local copy
stale, File missing locally, Conflict detected. Confirm there is a visual for the workspace-
creation success state.

**Acceptance Scenarios**:

1. **Given** the reviewer opens the first-launch section, **When** they view the iCloud-available state, **Then** a workspace creation or opening confirmation is shown with a progress indicator.
2. **Given** the reviewer views the "Not signed in to iCloud" state, **When** they read the screen, **Then** a clear explanation and a call-to-action to sign in or use a local fallback is shown.
3. **Given** the reviewer views the "Container unavailable" state, **When** they read the screen, **Then** a diagnostic message and recovery step are shown.
4. **Given** the reviewer views the "Conflict detected" state, **When** they read the screen, **Then** the conflict is described clearly with a resolution path (not just a generic error).
5. **Given** the reviewer views the "Syncing" state, **When** they read the screen, **Then** a progress indicator communicates that iCloud is working and the user should wait.
6. **Given** workspace creation completes successfully, **When** the reviewer views the success state, **Then** the workspace path, workspace ID, and a "start using the app" action are shown.

---

### User Story 4 - Workspace Sync Status and Indexing States (Priority: P4)

A reviewer can see how the app communicates ongoing workspace status in two contexts: the
persistent status element in the toolbar (showing current sync state at all times) and the
per-file sync badge that appears on individual files in any file-referencing view. They can
also see the loading and indexing state — what the user sees from the moment the app launches
until projections are ready to display.

**Why this priority**: Sync status and indexing progress are platform-layer concerns that affect
every module view. The loading state in particular determines what users see during the
first-launch experience and after any reindex. These need to be designed before module views
are built so the module views can be designed around them.

**Independent Test**: Inspect the toolbar sync status element. Confirm it shows four distinct
states: synced, syncing, stale, error. Inspect a file-path chip or file reference in any module
view. Confirm per-file sync badge states are visible. Navigate to a prototype state representing
the indexing/loading experience and confirm it is designed as a distinct screen or overlay.

**Acceptance Scenarios**:

1. **Given** the reviewer inspects the toolbar sync pill, **When** they cycle through its states, **Then** at least four visual states are represented: synced (green), syncing (animated or pulsing), local copy stale (amber), and error / unavailable (red).
2. **Given** the reviewer inspects a file path chip or file reference in a detail view, **When** they look for a sync badge, **Then** four per-file sync states are visually distinct: available locally, syncing, missing locally, conflict.
3. **Given** the app has launched but indexing is in progress, **When** the reviewer views the loading/indexing state, **Then** a file count, a progress indicator, and any classification warnings detected during scan are shown — not a blank screen or spinner alone.
4. **Given** the reviewer views the "file missing locally" state for a specific file reference, **When** they read the file path chip, **Then** the badge communicates that the file is not available locally with a recovery hint (e.g., "waiting for iCloud").

---

### User Story 5 - Validation Issue Card and Repair Preview Panel (Priority: P5)

A reviewer can see the designed treatment for validation issues and repair flows. A validation
issue card shows severity by icon and color, the affected file path, a human-readable
description, and a badge indicating whether the issue is auto-repairable or manual-only.
The repair preview panel shows a diff-style before/after view of the affected rows, a note
about the backup that will be created, and apply/cancel actions. These designs are surfaced
inline in the Overview Issues table and in the right inspector panel.

**Why this priority**: Validation and repair are core to the app's value proposition (PRD
principle VII — Repair When Safe). The issue card and repair preview are referenced across
multiple modules. Getting them designed now means every module view can be built with the
correct affordance for surfacing issues.

**Independent Test**: Open the Overview Issues table. Confirm each issue row shows a severity
color/icon, a file path, a description, and a repairable/manual badge. Select a repairable
issue. Confirm the inspector shows a diff-style preview with apply/cancel controls and a backup
note. Select a manual-only issue. Confirm the inspector shows a different treatment with open-
in-editor and reveal-in-Finder actions.

**Acceptance Scenarios**:

1. **Given** the reviewer views the Overview Issues table, **When** they read an error-severity issue row, **Then** the row shows: a red severity indicator, the affected file path, a short description, and a "manual" or "repairable" badge.
2. **Given** the reviewer views a warning-severity or info-severity issue, **When** they compare severities, **Then** all three severity indicators (error, warning, info) are visually distinct from one another — color and icon all differ.
3. **Given** the reviewer selects a repairable issue, **When** the inspector opens, **Then** a diff-style panel shows the before and after state of the affected rows, a note confirms a backup will be created, and Apply and Cancel buttons are present.
4. **Given** the reviewer selects a manual-only issue, **When** the inspector opens, **Then** no diff panel or Apply button is shown. Instead, an explanation and Reveal in Finder / Open in Editor actions are present.
5. **Given** the reviewer views any panel that references a source file, **When** they see a file path chip, **Then** the chip links to either the inspector source view or an open-in-editor action.

---

### User Story 6 - Overview Dashboard (Priority: P6)

A reviewer navigates to Overview and sees the updated dashboard: no filter bar, exactly five
KPI cards, a month-over-month trend panel, and an inline Issues table. Monthly Snapshots and
Annual Snapshots are not accessible. Each KPI card navigates to its corresponding module.

**Why this priority**: Overview is the landing view and the most referenced screen in any design
review. Its filter bar and extra KPI cards are the most visible mismatches with the PRD.

**Independent Test**: Navigate to Overview. Confirm no filter bar is present. Count KPI cards —
expect exactly 5. Locate the Issues table below the charts. Try to access Monthly Snapshots or
Annual Snapshots — neither should be reachable.

**Acceptance Scenarios**:

1. **Given** the reviewer is on Overview, **When** they look above the KPI grid, **Then** no filter bar, period selector, search field, or view switcher is present.
2. **Given** the Overview is shown, **When** the reviewer counts the KPI cards, **Then** exactly five appear: Budget (monthly cash flow), Savings (total savings balance), Investments (total investment value), Business NI (YTD net income for Consulting LLC), Taxes (estimated return).
3. **Given** the Overview is shown, **When** the reviewer scrolls down, **Then** an Issues table is present showing validation issues grouped by severity with repairable badges — using the issue card design from User Story 5.
4. **Given** the reviewer clicks any KPI card, **When** navigation occurs, **Then** they land on the corresponding module view (with Business NI navigating to the Consulting LLC detail under Accounts).

---

### User Story 7 - Budget Module Updated (Priority: P7)

A reviewer navigates to Budget and sees the pie chart overview, the trailing average column in
the category table, and the absence of Rules anywhere in the Budget section.

**Why this priority**: The Budget module has the clearest Round 1 design direction — pie chart
added, trailing averages added, Rules removed. These are also among the most visually impactful
changes for the macOS app design.

**Independent Test**: Navigate to Budget. Confirm a pie chart showing spending breakdown is
present. Confirm a trailing average column exists in the category table. Confirm no Rules
entry is reachable. Confirm the main view is labeled "Overview" not "Current Month."

**Acceptance Scenarios**:

1. **Given** the reviewer opens Budget, **When** the overview loads, **Then** a pie or donut chart shows fixed expenses, discretionary, savings, and investments as percentages of monthly net income.
2. **Given** the reviewer views the category variance table, **When** they read column headers, **Then** a 3-month trailing average column is present alongside planned, actual, and variance.
3. **Given** fewer than 3 months of data are available for a category, **When** the trailing average is shown, **Then** it displays a partial value with a visual cue indicating limited data — not a blank or zero.
4. **Given** the reviewer searches for Budget Rules in the sidebar and in the Budget views, **When** they look thoroughly, **Then** no Rules entry, link, or view is accessible anywhere.

---

### User Story 8 - Savings & Investments Unified Module (Priority: P8)

A reviewer finds Savings & Investments as a single merged section. Goals and Portfolio are
sub-views within it. The Benchmarks view shows a heat map table with 8 time-period columns
instead of a single line chart.

**Why this priority**: The module merge is the most significant structural navigation change.
Until it is reflected in the prototype, the design team cannot evaluate whether the unified
layout works for both goal tracking and portfolio management.

**Independent Test**: Confirm no separate Savings Goals or Investments top-level entries exist.
Navigate to Savings & Investments and confirm both Goals and Portfolio sub-views are present.
Open Benchmarks and confirm a table with 8 period column headings (D, W, M, 3M, 6M, 1Y, 3Y, 5Y)
is present.

**Acceptance Scenarios**:

1. **Given** the reviewer inspects the sidebar, **When** they look for Savings Goals and Investments as separate items, **Then** neither exists — only Savings & Investments appears.
2. **Given** the reviewer opens Savings & Investments, **When** they navigate within it, **Then** both goal cards and portfolio holdings are accessible from the same section.
3. **Given** the reviewer opens Benchmarks under Portfolio, **When** the view loads, **Then** a heat map table appears with exactly 8 period columns: D, W, M, 3M, 6M, 1Y, 3Y, 5Y — not a single line chart.
4. **Given** the reviewer reads the heat map, **When** they locate an account row and a time period cell, **Then** the cell shows a % growth value (or a dash for unavailable data) — not a chart shape.

---

### User Story 9 - Taxes Expanded and Accounts Placeholder (Priority: P9)

A reviewer finds a Deductions sub-view in the Taxes section showing four labeled deduction
groups. The Taxes overview shows a per-account effective rate table. A reviewer navigating
to Accounts finds a new section with a placeholder card grid showing mock accounts and an
aggregate header.

**Why this priority**: Taxes expansion and the Accounts module are two of the largest additions
from the Round 1 PRD update. Both need to be in the prototype so the design can be validated
before the macOS build begins.

**Independent Test**: Expand Taxes in the sidebar and confirm a Deductions sub-item exists.
Open it and confirm four labeled sections are visible. Open Current Tax Year and confirm a per-
account rate table is present. Navigate to Accounts and confirm the section exists with a card
grid showing at least 2 mock account cards.

**Acceptance Scenarios**:

1. **Given** the reviewer expands Taxes, **When** they read sub-items, **Then** Deductions appears alongside Current Tax Year, Estimated Payments, Gains & Income, and Prep Checklist.
2. **Given** the reviewer opens Deductions, **When** the view loads, **Then** four labeled sections appear: Standard Deduction, Above-the-Line Deductions, Itemized Deductions (Schedule A), Self-Employed Deductions (Schedule C).
3. **Given** the reviewer opens Current Tax Year, **When** the view loads, **Then** a table shows taxable income, taxes paid, taxes owed, and effective rate per account.
4. **Given** the reviewer navigates to Accounts, **When** the view loads, **Then** an aggregate header row and a card grid with at least 2 placeholder account cards are shown — each card shows an account name, account group label, and placeholder values for monthly cash inflow and YTD net income.

---

### Edge Cases

- Empty state for Accounts: when no mock accounts exist, show a labeled empty state with an "Add account" placeholder — not a blank screen.
- Budget pie chart with all-zero data: show an empty state chart with a message, not a broken or invisible chart.
- Benchmark heat map with missing data for a cell: show a dash (—), not a blank cell or error.
- Trailing average with < 3 months data: show partial average with a visual cue, not zero or blank.
- Validation issue selected with no repair preview available: show a manual review treatment with no Apply button — never show an Apply button for manual-only issues.
- Right panel open when navigating: panel must close and selection must clear on every navigation change without exception.
- iCloud unavailable on first launch: show the "Container unavailable" state with a recovery action — never show a blank app shell.

---

## Requirements *(mandatory)*

### Functional Requirements

**Navigation and shell (Round 1 alignment)**
- **FR-001**: The `NAV` array in `app.js` MUST contain exactly these top-level sections in order: Overview, Accounts, Budget, Savings & Investments, Taxes, Settings.
- **FR-002**: Monthly Snapshots, Annual Snapshots, and Budget Rules MUST be removed from all sub-item lists and their corresponding view functions MUST be unreachable from navigation.
- **FR-003**: Savings Goals and Investments MUST be replaced by a single Savings & Investments top-level section with sub-navigation covering both goals and portfolio.
- **FR-004**: Notes, Issues, and Files MUST be removed from top-level navigation. Issues data is surfaced in the Overview view instead.

**Right panel**
- **FR-005**: The inspector panel MUST be hidden on initial load and on every navigation change.
- **FR-006**: The inspector MUST appear as a slide-over overlay (not pushing content) when a selection is made.

**First-launch onboarding**
- **FR-007**: A first-launch / onboarding screen or flow MUST be added to the prototype showing all seven iCloud workspace states: Available, Not signed in, Container unavailable, Syncing, Local copy stale, File missing locally, Conflict detected.
- **FR-008**: Each iCloud state MUST show a distinct visual treatment: at minimum a title, a description, and where appropriate a recovery action.
- **FR-009**: A workspace-creation success state MUST be shown with workspace path, workspace ID, and a call-to-action to proceed.

**Sync status and indexing**
- **FR-010**: The toolbar sync pill MUST display four visually distinct states: synced, syncing, stale, and error/unavailable — using distinct colors and/or icons for each.
- **FR-011**: File path chips and file references in detail/inspector views MUST support four per-file sync badge states: available locally, syncing, missing locally, conflict — shown as a small badge on or adjacent to the chip.
- **FR-012**: A loading/indexing state MUST be designed showing: file count scanned, a progress indicator, and any classification warnings encountered — this MUST be a distinct designed state, not a generic spinner.

**Validation issue card and repair preview**
- **FR-013**: The Overview Issues table rows MUST each show a severity indicator (color + icon), affected file path, a short description, and a repairable/manual badge.
- **FR-014**: Error and warning severity MUST be visually distinct from each other and from info (different colors and icons).
- **FR-015**: Selecting a repairable issue in the inspector MUST show a diff-style before/after panel, a backup confirmation note, and Apply/Cancel actions.
- **FR-016**: Selecting a manual-only issue in the inspector MUST show an explanation and Reveal in Finder / Open in Editor actions — no Apply button.

**Overview (Round 1 alignment)**
- **FR-017**: The Overview view MUST NOT render a filter bar.
- **FR-018**: The Overview KPI grid MUST contain exactly five cards: Budget, Savings, Investments, Business, Taxes (where Business NI links to accounts-entity-consulting-llc).

**Budget (Round 1 alignment)**
- **FR-019**: The Budget Overview MUST include a pie or donut chart showing spending breakdown as a percentage of monthly net income.
- **FR-020**: The category variance table MUST include a 3-month trailing average column.

**Savings & Investments (Round 1 alignment)**
- **FR-022**: The Benchmarks view MUST show a heat map table with columns for D, W, M, 3M, 6M, 1Y, 3Y, 5Y — one row per investment account plus an S&P 500 row.

**Taxes (Round 1 alignment)**
- **FR-023**: A Deductions sub-view MUST be added to Taxes showing four labeled groups: Standard Deduction, Above-the-Line Deductions, Itemized Deductions (Schedule A), Self-Employed Deductions (Schedule C).
- **FR-024**: The Current Tax Year view MUST include a per-account effective rate table.

**Accounts (new section)**
- **FR-025**: An Accounts section MUST render a card grid grouped by customizable theme/entity (Personal Assets, Place of Employment, Business Entities) and support dedicated detail dashboards for each theme type (including business P&L dashboard for Business entities).

### Key Entities

- **Prototype navigation structure**: The `NAV` constant in `app.js` — the authoritative array for sidebar structure.
- **Inspector panel**: `<aside class="inspector">` in `index.html` and the `renderInspector` / `select` functions — currently always visible, needs closed-default slide-over behavior.
- **Onboarding flow**: A new screen or overlay to be added, covering first-launch workspace states.
- **Toolbar sync pill**: The `<div class="sync-pill">` in the sidebar footer — to be promoted to a multi-state toolbar element with distinct visual states.
- **Validation issue card**: The issue row design within the Overview Issues table and as shown in the inspector.
- **Repair preview panel**: The inspector content shown when a repairable issue is selected — currently has an "Apply" button but lacks a proper diff-style before/after treatment.
- **Benchmark heat map**: The `viewInvestmentsBenchmarks()` function — currently a line chart, needs a table component.
- **Budget pie chart**: New component inside the renamed `viewBudgetOverview()`, using the existing `donutChart` SVG helper.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every open design task listed under Phase 1 and Phase 2 in `docs/roadmap-v1.md` is represented by at least one designed prototype screen — none remain undesigned.
- **SC-002**: A reviewer walking through every sidebar section finds zero v2-deferred views (Notes, Issues standalone, Files, Budget Rules, Monthly Snapshots, Annual Snapshots) and no top-level Business section reachable from navigation.
- **SC-003**: Every v1 section (Overview, Accounts, Budget, Savings & Investments, Taxes, Settings) renders without a JavaScript error in the browser console.
- **SC-004**: A reviewer can identify the correct designed treatment for all 7 iCloud workspace states by navigating the onboarding flow — no state is missing or shown as a placeholder text block.
- **SC-005**: A reviewer can walk through the full repair flow — select an issue, read the diff preview, read the backup confirmation note — without leaving the prototype.
- **SC-006**: A reviewer opening the prototype on a fresh load observes the right panel is not visible anywhere before they make a selection.
- **SC-007**: Any engineer starting Phase 1 or Phase 2 development can answer their open design questions by opening the prototype — no design decisions in those phases remain unresolved in the prototype.

## Assumptions

- All changes are confined to `design/prototype/` (`app.js`, `index.html`, `styles.css`, `data.js`). No other files are created.
- Mock and placeholder data is acceptable throughout. Data accuracy is not a goal — visual design fidelity and interaction pattern clarity are.
- The existing chart helpers (`donutChart`, `lineChart`, `barChart`) and the `el()` utility are available for all new view functions without modification.
- The onboarding flow can be implemented as a modal overlay on the existing shell, a dedicated view navigable from Settings, or a standalone mode triggered by a "Show onboarding" button — the implementation pattern is a design decision for the prototype author.
- The first-launch flow does not need to be the app's actual initial route in the prototype; it needs to be reachable and fully designed.
- The per-file sync badge for file path chips can be a small colored dot or icon added to the existing `.path-chip` CSS class — no structural HTML changes to existing chips are required.
- The repair preview "diff" does not need to be a true computed diff; hardcoded before/after row text that communicates the visual pattern is sufficient.
- This spec will be updated when Phase 3 and beyond design tasks are ready to be added to the prototype scope.
