# Feature Specification: Prototype as Design Source of Truth

**Feature Branch**: `001-prototype-prd-alignment`
**Created**: 2026-06-08
**Last updated**: 2026-06-14 (Round 5 — interactive prototype pass)
**Status**: Active (living document)
**Prototype location**: `prototype/` (HTML/CSS/JS, no build step)

## Purpose

The prototype at `prototype/` is the primary design and interaction reference for the v1 macOS
app. Every design decision that affects layout, interaction patterns, information hierarchy,
visual treatment, or user flow should be visible and exercisable here before it is built in Swift.

This spec defines the full scope of what the prototype must cover and is updated each round as
new requirements are added. It has two responsibilities:

1. **Design reference** — every v1 screen, state, and module view is represented so the team
   can review information hierarchy and layout decisions without touching Swift code.

2. **Interaction reference** — every core user flow (create, import, export, repair, persist)
   is exercisable with real mock data so reviewers can evaluate the end-to-end experience,
   not just the visual design.

The prototype is the reference for the macOS app — not the other way around. This spec is the
authoritative document for what the prototype must do. Prototype-specific implementation
decisions (storage model, export column shapes, modal patterns) belong here, not in
`docs/product-requirements.md` or `docs/technical-design.md`.

---

## Round History

| Round | Date | Summary |
|---|---|---|
| Round 1 (r1) | 2026-06-08 | Initial alignment spec: navigation restructure, merged modules, updated views. Scope: visual fidelity only. |
| Round 5 (r5) | 2026-06-14 | Interactive pass: localStorage persistence layer, create/import/export/repair/checklist flows, live search, filter menus, OS-action toasts, Settings reset control. |

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
to the user. Recovery actions on each state are wired — "Start using app" navigates
to Accounts; other OS-level actions display an honest toast explaining they would be
triggered by the native macOS app.

**Why this priority**: The onboarding and workspace resolution flow is the first thing every
user sees. The seven sync states are defined in the technical design but have never been
designed visually. This work unblocks the Phase 1 development team from having to invent
UI patterns for error states on the fly.

**Independent Test**: Open the prototype and navigate to the onboarding / first-launch section.
Confirm all seven iCloud states are shown. Confirm the recovery action buttons are clickable
and produce a response (navigation or toast) rather than doing nothing.

**Acceptance Scenarios**:

1. **Given** the reviewer opens the first-launch section, **When** they view the iCloud-available state, **Then** a workspace creation or opening confirmation is shown with a progress indicator.
2. **Given** the reviewer views the "Not signed in to iCloud" state, **When** they read the screen, **Then** a clear explanation and a call-to-action to sign in or use a local fallback is shown.
3. **Given** the reviewer views the "Container unavailable" state, **When** they read the screen, **Then** a diagnostic message and recovery step are shown.
4. **Given** the reviewer views the "Conflict detected" state, **When** they read the screen, **Then** the conflict is described clearly with a resolution path (not just a generic error).
5. **Given** the reviewer views the "Syncing" state, **When** they read the screen, **Then** a progress indicator communicates that iCloud is working and the user should wait.
6. **Given** workspace creation completes successfully, **When** the reviewer views the success state, **Then** the workspace path, workspace ID, and a "Start using app" action are shown — clicking "Start using app" navigates to the Accounts screen.

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
about the backup that will be created, and apply/cancel actions. Individual repair and bulk
repair are both exercisable — clicking "Apply repair" in the inspector or "Apply repairable
fixes" on Overview produces a real state change, decrements the issue count, and persists.

**Why this priority**: Validation and repair are core to the app's value proposition. The issue
card and repair preview are referenced across multiple modules. Getting them designed and
interactive now means every module view can be built with the correct affordance for surfacing
issues.

**Independent Test**: Open the Overview Issues table. Confirm each issue row shows a severity
color/icon, a file path, a description, and a repairable/manual badge. Select a repairable
issue. Confirm the inspector shows a diff-style preview with apply/cancel controls and a backup
note. Click "Apply repair" — confirm the issue disappears and the count decrements. Click
"Apply repairable fixes" on the Overview header — confirm all remaining repairable issues are
removed in one action.

**Acceptance Scenarios**:

1. **Given** the reviewer views the Overview Issues table, **When** they read an error-severity issue row, **Then** the row shows: a red severity indicator, the affected file path, a short description, and a "manual" or "repairable" badge.
2. **Given** the reviewer views a warning-severity or info-severity issue, **When** they compare severities, **Then** all three severity indicators (error, warning, info) are visually distinct from one another — color and icon all differ.
3. **Given** the reviewer selects a repairable issue, **When** the inspector opens, **Then** a diff-style panel shows the before and after state of the affected rows, a note confirms a backup will be created, and Apply and Cancel buttons are present.
4. **Given** the reviewer clicks Apply repair in the inspector, **When** the action completes, **Then** the issue is removed from the table, the issue count in the toolbar decrements, a toast confirms "backup saved", and the change persists after a page refresh.
5. **Given** the reviewer selects a manual-only issue, **When** the inspector opens, **Then** no diff panel or Apply button is shown. Instead, an explanation and Reveal in Finder / Open in Editor actions are present.
6. **Given** the reviewer clicks "Apply repairable fixes" on Overview, **When** the action completes, **Then** all auto-repairable issues are removed in one step, a toast confirms how many were repaired and that backups were saved, and the change persists.

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
the category table, and the absence of Rules anywhere in the Budget section. The reviewer can
import transactions from a CSV file or enter one manually, add new categories, and export the
ledger or category list.

**Why this priority**: The Budget module has the clearest Round 1 design direction — pie chart
added, trailing averages added, Rules removed — and now also hosts the core transaction
import/add flows that drive the most frequent user action in the app.

**Independent Test**: Navigate to Budget. Confirm a pie chart showing spending breakdown is
present. Confirm a trailing average column exists in the category table. Confirm no Rules
entry is reachable. Click "Import CSV" — confirm a modal opens with a file upload section and
a manual-entry fallback. Add a transaction and confirm it appears in the ledger.

**Acceptance Scenarios**:

1. **Given** the reviewer opens Budget, **When** the overview loads, **Then** a pie or donut chart shows fixed expenses, discretionary, savings, and investments as percentages of monthly net income.
2. **Given** the reviewer views the category variance table, **When** they read column headers, **Then** a 3-month trailing average column is present alongside planned, actual, and variance.
3. **Given** fewer than 3 months of data are available for a category, **When** the trailing average is shown, **Then** it displays a partial value with a visual cue indicating limited data — not a blank or zero.
4. **Given** the reviewer searches for Budget Rules in the sidebar and in the Budget views, **When** they look thoroughly, **Then** no Rules entry, link, or view is accessible anywhere.
5. **Given** the reviewer clicks "Import CSV", **When** the modal opens, **Then** a file upload section appears with the accepted CSV format documented on-screen (`date, merchant, description, category, amount`) alongside a manual-entry form as a fallback.
6. **Given** the reviewer clicks "New category", **When** they complete the form, **Then** the new category appears in the category list and the change persists after a page refresh.

---

### User Story 8 - Savings & Investments Unified Module (Priority: P8)

A reviewer finds Savings & Investments as a single merged section. Goals and Portfolio are
sub-views within it. The Benchmarks view shows a heat map table with 8 time-period columns
instead of a single line chart. The reviewer can add a savings goal and see it appear
immediately with the sidebar goal count updated.

**Why this priority**: The module merge is the most significant structural navigation change.
Until it is reflected in the prototype, the design team cannot evaluate whether the unified
layout works for both goal tracking and portfolio management.

**Independent Test**: Confirm no separate Savings Goals or Investments top-level entries exist.
Navigate to Savings & Investments and confirm both Goals and Portfolio sub-views are present.
Click "New goal", complete the form, and confirm the goal card appears and the sidebar badge
count increments. Open Benchmarks and confirm a table with 8 period column headings.

**Acceptance Scenarios**:

1. **Given** the reviewer inspects the sidebar, **When** they look for Savings Goals and Investments as separate items, **Then** neither exists — only Savings & Investments appears.
2. **Given** the reviewer opens Savings & Investments, **When** they navigate within it, **Then** both goal cards and portfolio holdings are accessible from the same section.
3. **Given** the reviewer opens Benchmarks under Portfolio, **When** the view loads, **Then** a heat map table appears with exactly 8 period columns: D, W, M, 3M, 6M, 1Y, 3Y, 5Y — not a single line chart.
4. **Given** the reviewer reads the heat map, **When** they locate an account row and a time period cell, **Then** the cell shows a % growth value (or a dash for unavailable data) — not a chart shape.
5. **Given** the reviewer clicks "New goal" and completes the form, **When** the modal is submitted, **Then** the new goal card appears in the Goals view, the sidebar goals badge increments, and the goal persists after a page refresh.

---

### User Story 9 - Taxes Expanded and Accounts Dashboard (Priority: P9)

A reviewer finds a Deductions sub-view in the Taxes section showing four labeled deduction
groups. The Taxes overview shows a per-account effective rate table and an "Export prep
packet" action that downloads a real Markdown file. The Tax Prep Checklist items are
interactive — clicking one toggles its done state and persists. A reviewer navigating to
Accounts finds the full Accounts dashboard: a card grid grouped by theme (Personal Assets,
Place of Employment, Business Entities), with each entity card navigating to its own
dedicated dashboard with tabs for transactions, budget, and categories.

**Why this priority**: Taxes expansion and the Accounts module are two of the largest additions
from the Round 1 PRD update. Both need to be interactive so the design can be validated
before the macOS build begins.

**Independent Test**: Expand Taxes in the sidebar. Open Prep Checklist and confirm checkboxes
are clickable (state persists on refresh). Click "Export prep packet" and confirm a Markdown
file is downloaded. Navigate to Accounts and confirm the section exists with theme-grouped
entity cards. Click a business entity card and confirm a dedicated dashboard opens with a
transactions tab and import/export actions.

**Acceptance Scenarios**:

1. **Given** the reviewer expands Taxes, **When** they read sub-items, **Then** Deductions appears alongside Current Tax Year, Estimated Payments, Gains & Income, and Prep Checklist.
2. **Given** the reviewer opens Deductions, **When** the view loads, **Then** four labeled sections appear: Standard Deduction, Above-the-Line Deductions, Itemized Deductions (Schedule A), Self-Employed Deductions (Schedule C).
3. **Given** the reviewer opens Current Tax Year, **When** the view loads, **Then** a table shows taxable income, taxes paid, taxes owed, and effective rate per account.
4. **Given** the reviewer clicks a checklist item on the Tax Prep Checklist, **When** the click registers, **Then** the checkbox toggles immediately and the state persists after a page refresh.
5. **Given** the reviewer clicks "Export prep packet", **When** the action completes, **Then** a Markdown file is downloaded containing the prep checklist (GFM task list), estimated payments table, and deductions table.
6. **Given** the reviewer navigates to Accounts, **When** the view loads, **Then** entity cards are grouped by theme (Personal Assets, Place of Employment, Business Entities) — each card showing entity name, type, and summary KPIs.
7. **Given** the reviewer clicks a Business entity card, **When** the entity dashboard opens, **Then** a tab bar provides Dashboard, Transactions, Budgets, and Categories — and Import CSV and Export P&L actions are available.

---

### User Story 10 - Prototype Persistence and Reset (Priority: P1, Round 5)

A reviewer makes changes to the prototype during a review session — adds a goal, imports
transactions, repairs issues — and returns to the prototype after closing and reopening the
browser tab. All changes from the session are still present. A different reviewer opening the
prototype for the first time gets the unmodified seed data. In Settings, a "Reset prototype
data" control lets any reviewer return to the seed state with one action.

**Why this priority**: Without persistence, reviewers cannot conduct a meaningful interactive
session — every refresh wipes their work. With it, the prototype can be used to accumulate a
realistic data state for demo and review purposes.

**Independent Test**: Add a savings goal. Reload the page. Confirm the goal still appears. Open
Settings and click "Reset prototype data". Confirm a confirmation modal appears. Confirm. Confirm
the prototype returns to its seed state and the added goal is gone.

**Acceptance Scenarios**:

1. **Given** a reviewer adds a goal and closes the browser tab, **When** they reopen the prototype, **Then** the added goal is still present.
2. **Given** a reviewer imports a transaction, **When** they reload the page, **Then** the imported transaction still appears in the ledger.
3. **Given** a reviewer applies a repair, **When** they reload the page, **Then** the issue count reflects the repaired state (the issue is gone).
4. **Given** Settings › Workspace shows a note about local edits, **When** the reviewer has made changes, **Then** the note says something like "You have local edits — these override the seed data."
5. **Given** the reviewer clicks "Reset prototype data", **When** they confirm in the dialog, **Then** all local edits are cleared and the prototype reloads in seed state.
6. **Given** the reviewer clicks "Reset prototype data" and then cancels the confirmation, **When** they return to Settings, **Then** no data has been changed.

---

### User Story 11 - Create Flows for Core Entities (Priority: P1, Round 5)

A reviewer can create new instances of every major entity in the prototype: savings goals,
transactions (manual), budget categories, accounts, business/employment entities, and estimated
tax payments. Each create flow opens a modal form with appropriate fields, validates required
inputs, and commits the new item to the data model on submit.

**Why this priority**: The PRD requires create/add flows for all core entities in v1. Without
them a reviewer cannot assess the information architecture of the create experience, which
affects the overall complexity budget of the app.

**Independent Test**: In each module, click the primary create action. Confirm a modal opens.
Submit without required fields — confirm validation error appears on the field. Fill the form
and submit — confirm the new item appears in the view and persists.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks "New goal", **When** they submit an empty Name field, **Then** a field-level error appears on the Name input and the modal does NOT close.
2. **Given** the reviewer fills all required fields and submits, **When** the modal closes, **Then** the new goal card appears immediately with correct values.
3. **Given** the reviewer clicks "New category" and completes the form, **When** the modal closes, **Then** the new category row appears in the Categories view.
4. **Given** the reviewer clicks "New entity" with type "business", **When** the modal closes, **Then** the new entity appears in the Business Entities section of the Accounts dashboard and in the sidebar.
5. **Given** the reviewer clicks "New payment" in Taxes › Estimated Payments, **When** the form is submitted, **Then** the new payment appears in the payments table with status "pending".
6. **Given** the reviewer clicks "New account", **When** the form is submitted, **Then** the new account appears in the Personal Assets section of the Accounts dashboard.

---

### User Story 12 - Transaction CSV Import (Priority: P1, Round 5)

A reviewer can import transactions into Budget or into a Business entity's ledger by uploading
a CSV file. The modal documents the expected column format on-screen. Uploading a valid file
adds all parseable rows to the ledger. A single-row manual entry is also available as a
fallback in the same modal.

**Why this priority**: CSV import is the primary data-entry path for users who have months of
bank/brokerage export history. Reviewing the import flow (file upload → confirmation →
ledger update) is essential before the macOS build begins.

**Independent Test**: Create a small CSV file with headers `date,merchant,description,category,amount`
and 2-3 data rows. Open Budget and click "Import CSV". Upload the file. Confirm all rows appear
in the ledger. Confirm the row count increased. Reload and confirm the rows persist.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks "Import CSV", **When** the modal opens, **Then** a file upload input for `.csv` files and a format hint (`date, merchant, description, category, amount`) are visible above the manual-entry form.
2. **Given** the reviewer uploads a valid CSV, **When** the file is processed, **Then** all parseable rows are added to the ledger, a success toast shows the row count, and the modal closes.
3. **Given** the reviewer uploads a CSV with no valid rows, **When** the file is processed, **Then** a warning toast says "No valid rows found in [filename]" and the modal stays open.
4. **Given** the reviewer skips file upload and fills the manual-entry form, **When** they submit, **Then** one transaction is added to the ledger.
5. **Given** the reviewer submits the modal with neither a file nor a merchant+amount, **When** the submit fires, **Then** a warning toast instructs them to choose a file or enter a merchant and amount — the modal stays open.

---

### User Story 13 - Export Flows (Priority: P2, Round 5)

A reviewer can click any Export button in the prototype and receive a real file download.
CSV exports contain columns from live data (including any creates or imports done in the
session). Markdown exports (Business P&L, Tax Prep Packet) produce structured documents
reviewers can read to assess the intended export format.

**Why this priority**: PRD §11 defines export as a v1 requirement. The prototype now demonstrates
the export formats concretely — reviewing the column choices and Markdown layouts validates
the spec before they are locked into the Swift implementation.

**Independent Test**: From Budget, click Export and confirm a CSV download occurs. From a
Business entity, click "Export P&L" and confirm a Markdown file downloads with the expected
structure. From Taxes, click "Export prep packet" and confirm a Markdown file downloads with
checklist, payments, and deductions.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks Export on any view, **When** the download occurs, **Then** the file contains live data from the current session state — any added/imported items are included.
2. **Given** no rows exist to export, **When** the reviewer clicks Export, **Then** a warning toast says "Nothing to export" and no download is triggered.
3. **Given** the reviewer downloads `transactions-2026-05.csv`, **When** they open it, **Then** columns are: `date, merchant, description, account, category, amount`.
4. **Given** the reviewer downloads a business P&L Markdown file, **When** they open it, **Then** it contains a Revenue / Expenses / Net income summary table and a Transactions table with columns: `Date, Merchant, Category, Amount, Deductible`.
5. **Given** the reviewer downloads the tax prep packet, **When** they open it, **Then** it contains a GFM task list for the prep checklist, an Estimated Payments table (`Quarter, Jurisdiction, Due, Amount, Paid, Status`), and a Deductions table (`Deduction, Type, Estimated, Status`).

---

### User Story 14 - Filter Menus and Live Search (Priority: P2, Round 5)

A reviewer interacting with filter bar chips in any module sees a dropdown menu appear when
they click a chip that has filterable options. Search inputs in Goals, Holdings, and
transaction ledgers live-filter the displayed rows as the reviewer types.

**Why this priority**: Filter and search are the primary navigation affordances within views
that have large datasets. They need to be demonstrably interactive before the macOS views
are built so that the interaction model can be validated.

**Independent Test**: Navigate to Budget Categories. Click the "Group" filter chip — confirm a
dropdown menu appears. Navigate to Savings Goals. Type in the search box — confirm cards are
filtered in real time.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks a filter chip that has predefined options, **When** the dropdown opens, **Then** the options are shown as a list and selecting one dismisses the menu.
2. **Given** a filter chip has no predefined options, **When** the reviewer clicks it, **Then** a toast informs them the filter is not yet data-driven.
3. **Given** the reviewer types in the Savings Goals search input, **When** they type two or more characters, **Then** only goal cards whose name matches the query are shown; others are hidden.
4. **Given** the reviewer types in the Holdings search input, **When** they type a ticker or name, **Then** only matching holding rows are shown.
5. **Given** the reviewer types in the transaction ledger search input (Budget or Business), **When** they type, **Then** only rows whose text content matches the query are shown.
6. **Given** the reviewer clears the search input, **When** the input is empty, **Then** all rows/cards are restored.

---

### Edge Cases

- **Empty state for Accounts**: when no mock accounts exist, show a labeled empty state with an "Add account" button — not a blank screen.
- **Budget pie chart with all-zero data**: show an empty state chart with a message, not a broken or invisible chart.
- **Benchmark heat map with missing data for a cell**: show a dash (—), not a blank cell or error.
- **Trailing average with < 3 months data**: show partial average with a visual cue, not zero or blank.
- **Validation issue selected with no repair preview available**: show a manual review treatment with no Apply button — never show an Apply button for manual-only issues.
- **Right panel open when navigating**: panel must close and selection must clear on every navigation change without exception.
- **iCloud unavailable on first launch**: show the "Container unavailable" state with a recovery action — never show a blank app shell.
- **Modal submit with empty required field**: show `field-error` styling on the first invalid field and do NOT close the modal or mutate DATA.
- **CSV import with no valid rows**: show a `warn` toast and keep the modal open — do NOT call `commit()`.
- **Export when the collection is empty**: show a `warn` toast ("Nothing to export") — do NOT trigger a download.
- **Bulk repair when no repairable issues remain**: show an `info` toast ("No repairable issues remaining") — do not mutate DATA.
- **"Reset prototype data" clicked**: a confirmation modal MUST appear before `Store.reset()` is called — the danger button alone MUST NOT reset without confirmation.
- **Settings dirty-state note**: when `Store.isDirty()` is true, Settings › Workspace MUST show a note; when false (seed state), no note.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Navigation and shell (Round 1)

- **FR-001**: The `NAV` array in `app.js` MUST contain exactly these top-level sections in order: Overview, Accounts, Budget, Savings & Investments, Taxes, Settings.
- **FR-002**: Monthly Snapshots, Annual Snapshots, and Budget Rules MUST be removed from all sub-item lists and their corresponding view functions MUST be unreachable from navigation.
- **FR-003**: Savings Goals and Investments MUST be replaced by a single Savings & Investments top-level section with sub-navigation covering both goals and portfolio.
- **FR-004**: Notes, Issues, and Files MUST be removed from top-level navigation. Issues data is surfaced in the Overview view instead.

#### Right panel (Round 1)

- **FR-005**: The inspector panel MUST be hidden on initial load and on every navigation change.
- **FR-006**: The inspector MUST appear as a slide-over overlay (not pushing content) when a selection is made.

#### First-launch onboarding (Round 1)

- **FR-007**: A first-launch / onboarding screen or flow MUST be added to the prototype showing all seven iCloud workspace states: Available, Not signed in, Container unavailable, Syncing, Local copy stale, File missing locally, Conflict detected.
- **FR-008**: Each iCloud state MUST show a distinct visual treatment: at minimum a title, a description, and where appropriate a recovery action.
- **FR-009**: The workspace-creation success state MUST show workspace path, workspace ID, and a "Start using app" action. Clicking "Start using app" MUST navigate to the Accounts screen.

#### Sync status and indexing (Round 1)

- **FR-010**: The toolbar sync pill MUST display four visually distinct states: synced, syncing, stale, and error/unavailable — using distinct colors and/or icons for each.
- **FR-011**: File path chips and file references in detail/inspector views MUST support four per-file sync badge states: available locally, syncing, missing locally, conflict — shown as a small badge on or adjacent to the chip.
- **FR-012**: A loading/indexing state MUST be designed showing: file count scanned, a progress indicator, and any classification warnings encountered — this MUST be a distinct designed state, not a generic spinner.

#### Validation issue card and repair preview (Round 1 + Round 5)

- **FR-013**: The Overview Issues table rows MUST each show a severity indicator (color + icon), affected file path, a short description, and a repairable/manual badge.
- **FR-014**: Error and warning severity MUST be visually distinct from each other and from info (different colors and icons).
- **FR-015**: Selecting a repairable issue in the inspector MUST show a diff-style before/after panel, a backup confirmation note, and Apply/Cancel actions.
- **FR-016**: Selecting a manual-only issue in the inspector MUST show an explanation and Reveal in Finder / Open in Editor actions — no Apply button.

#### Overview (Round 1)

- **FR-017**: The Overview view MUST NOT render a filter bar.
- **FR-018**: The Overview KPI grid MUST contain exactly five cards: Budget, Savings, Investments, Business, Taxes (where Business NI links to accounts-entity-consulting-llc).

#### Budget (Round 1)

- **FR-019**: The Budget Overview MUST include a pie or donut chart showing spending breakdown as a percentage of monthly net income.
- **FR-020**: The category variance table MUST include a 3-month trailing average column.

#### Savings & Investments (Round 1)

- **FR-022**: The Benchmarks view MUST show a heat map table with columns for D, W, M, 3M, 6M, 1Y, 3Y, 5Y — one row per investment account plus an S&P 500 row.

#### Taxes (Round 1)

- **FR-023**: A Deductions sub-view MUST be added to Taxes showing four labeled groups: Standard Deduction, Above-the-Line Deductions, Itemized Deductions (Schedule A), Self-Employed Deductions (Schedule C).
- **FR-024**: The Current Tax Year view MUST include a per-account effective rate table.

#### Accounts (Round 1)

- **FR-025**: An Accounts section MUST render a card grid grouped by customizable theme/entity (Personal Assets, Place of Employment, Business Entities) and support dedicated detail dashboards for each theme type (including business P&L dashboard for Business entities).

---

#### Persistence layer (Round 5)

- **FR-026**: A `store.js` module MUST implement the prototype persistence layer. It MUST expose: `hydrate()`, `save()`, `reset()`, `isDirty()`, and `syncDerived()`. The module MUST be loaded between `data.js` and `app.js` in `index.html`.
- **FR-027**: `Store.hydrate()` MUST read from `localStorage` key `finance-proto-workspace-v1`. If saved data exists, it overlays the following 16 collections onto the seed `DATA`: `goals, transactions, categories, rules, accounts, entities, estimatedPayments, deductions, taxChecklist, issues, holdings, sleeves, sleeveTargets, notes, businessCategories, businessBudgets`. After overlay, `syncDerived()` MUST be called to recompute `DATA.businessTransactions` (all transactions with an `id` matching `/^BX-/`).
- **FR-028**: `Store.save()` MUST serialize the same 16 collections to `localStorage` and call `syncDerived()` before writing.
- **FR-029**: `Store.reset()` MUST call `localStorage.removeItem(key)` and then `location.reload()`. This is the only way to return to seed state.
- **FR-030**: Every mutation to `DATA` in the prototype MUST go through the `commit()` function. `commit()` MUST call `Store.save()`, then re-render the sidebar, center, and inspector in that order.

#### Interaction infrastructure (Round 5)

- **FR-031**: A reusable `openModal({ title, subtitle, fields, body, submitLabel, cancelLabel, onSubmit })` function MUST be implemented. Fields support types: `text`, `number`, `date`, `select`, `textarea`. A `file` upload section is supported via `body`. Required fields MUST show `field-error` styling and block submit if empty. `onSubmit` receives field values and returns `true` to close the modal or `false` to keep it open.
- **FR-032**: A `toast(message, kind)` function MUST show a transient notification anchored to the bottom-right of the viewport. Kind `ok` = green, `warn` = amber, `info` = neutral. The toast MUST auto-dismiss.
- **FR-033**: An `openMenu(anchor, options, onPick)` function MUST show a positioned dropdown (`.proto-menu`) relative to the trigger element. It MUST close on outside click.
- **FR-034**: Filter bar chips that have an `options` array MUST call `openMenu` on click. Filter bar chips without options MUST show a `toast` fallback explaining the filter is not yet data-driven.
- **FR-035**: Buttons that invoke OS-level actions (`Reveal in Finder`, `Open in editor`, `Download` on the indexing screen) MUST call `osAction(label, target)`, which shows a `toast` explaining the action would be triggered by the native macOS app. They MUST NOT show a broken or empty state.

#### Create flows (Round 5)

- **FR-036**: `New goal` MUST open a modal with fields: Name (text, required), Target amount (number, required), Monthly target (number), Target date (date). On submit, a new goal object MUST be pushed to `DATA.goals` and `commit()` called. The sidebar goals badge MUST reflect the updated count.
- **FR-037**: `Import CSV` / `Import transactions` MUST open a modal with a file upload section (`.csv` files) and a manual-entry fallback form with fields: Date (date), Merchant (text), Description (text), Category (select from `DATA.categories` / `DATA.businessCategories`), Amount (number). On CSV file upload, `ingestTransactionCSV(text, { entityId, business })` MUST parse lines with format `date, merchant, description, category, amount` (header row optional; negative amounts = expenses). On manual entry, `addTransaction` MUST be called. In both cases `commit()` is called on success.
- **FR-038**: `New category` MUST open a modal with fields: Name (text, required), Group (select: housing/food/transport/utilities/personal/insurance/savings/investments), Planned monthly (number). On submit, pushes to `DATA.categories` and calls `commit()`.
- **FR-039**: `New entity` MUST open a modal with fields: Display name (text, required), Type (select: business/employment/personal), Tax ID (text). On submit, pushes to `DATA.entities` and calls `commit()`. The new entity MUST appear in the Accounts dashboard and in the sidebar nav.
- **FR-040**: `New account` / `Add account` / `Add Asset` MUST open a modal with fields: Name (text, required), Type (select: checking/savings/investment/loan/credit), Institution (text), Balance (number). On submit, pushes to `DATA.accounts` and calls `commit()`.
- **FR-041**: `Import Paystub` (Employment entity) MUST open a modal with fields: Pay period (date), Gross pay (number), Net pay (number). On submit, adds a payroll credit transaction to `DATA.transactions` and calls `commit()`.
- **FR-042**: `New payment` (Taxes › Estimated Payments) MUST open a modal with fields: Quarter (select: 1/2/3/4), Year (number), Jurisdiction (select: Federal/State), Due date (date), Amount (number). On submit, pushes to `DATA.estimatedPayments` with `status: 'pending'` and calls `commit()`.
- **FR-043**: `Import prices` (Portfolio / Holdings) MUST open a modal with fields: Holding (select from `DATA.holdings` tickers), New price (number, required). On submit, the selected holding's `price` field MUST be updated and `commit()` called.
- **FR-044**: `Rebalance plan` MUST compute a drift-to-trade table (sleeve actual weight vs target weight, showing only sleeves with |drift| > 0.5%) and display it in a modal. The modal MUST include an "Export plan" action that downloads `rebalance-plan.csv` with columns: `ticker, sleeve, drift, trade_usd`.
- **FR-045**: Business Categories `New` MUST open a modal with fields: Name (text, required), Group (text). On submit, pushes to `DATA.businessCategories` and calls `commit()`.

#### Repair and checklist (Round 5)

- **FR-046**: Inspector `Apply repair` button MUST call `applyRepair(id)`, which removes the issue from `DATA.issues`, decrements `DATA.workspace.issueCount`, closes the inspector, shows a `toast` ("1 issue repaired · backup saved"), and calls `commit()`.
- **FR-047**: Overview `Apply repairable fixes` MUST bulk-remove all issues where `repairable === true` from `DATA.issues`, update `DATA.workspace.issueCount`, show a `toast` ("{n} issues repaired · backups saved"), and call `commit()`. If no repairable issues exist, it MUST show an `info` toast instead.
- **FR-048**: Tax prep checklist items MUST call `toggleChecklistItem(id)` on click, which flips the `done` field and calls `commit()`. The visual checkbox state MUST update immediately via re-render.

#### Reindex (Round 5)

- **FR-049**: `Reindex` buttons MUST call `runReindex()`, which sets `state.syncState = 'syncing'`, re-renders the sidebar, waits ~2 seconds, then sets `state.syncState = 'synced'`, re-renders again, and shows an `info` toast.

#### Export shapes (Round 5)

All exports use the `exportCSV(filename, headers, rows)` or `exportMarkdown(filename, md)` helpers, which produce real browser file downloads from live `DATA`.

- **FR-050**: Budget Overview `Export` → `transactions-2026-05.csv` — columns: `date, merchant, description, account, category, amount` (personal non-income transactions only, i.e. `category !== 'income'` and `id` not matching `/^BX-/`).
- **FR-051**: Budget History `Export` → `budget-history.csv` — columns: `month, planned, actual, variance`.
- **FR-052**: Budget Categories `Export` → `categories.csv` — columns: `id, name, group, planned`.
- **FR-053**: Savings Goals `Export` → `savings-goals.csv` — columns: `name, target, balance, monthly_target, target_date`.
- **FR-054**: Portfolio Overview `Export` → `holdings.csv` — columns: `ticker, name, account, sleeve, qty, price, basis, market_value` (where `market_value = round(qty × price)`).
- **FR-055**: Holdings view `Export` → `holdings.csv` — columns: `ticker, name, account, sleeve, qty, price, basis`.
- **FR-056**: Overview Issues `Export` → `overview-issues.csv` — columns: `severity, group, title, file, repairable`.
- **FR-057**: Rebalance plan `Export plan` → `rebalance-plan.csv` — columns: `ticker, sleeve, drift, trade_usd`.
- **FR-058**: Business / Account Entity `Export P&L` → `{entityId}-pl.md` — Markdown with: (1) heading `# {Entity display} — P&L (May 2026)`, (2) table with rows `Revenue`, `Expenses`, `Net income`, (3) `## Transactions` section with table columns `Date, Merchant, Category, Amount, Deductible`.
- **FR-059**: Taxes `Export prep packet` → `2026-tax-prep-packet.md` — Markdown with: (1) `## Prep checklist` as a GFM task list (`- [x]` / `- [ ]` per item with optional due date), (2) `## Estimated payments` table with columns `Quarter, Jurisdiction, Due, Amount, Paid, Status`, (3) `## Deductions` table with columns `Deduction, Type, Estimated, Status`.

#### Settings (Round 5)

- **FR-060**: Settings › Workspace MUST include a "Reset prototype data" button styled as `.btn.btn-danger`. Clicking it MUST open a confirmation modal. Only on confirmation MUST `Store.reset()` be called.
- **FR-061**: Settings › Workspace MUST display a live note when `Store.isDirty()` is `true` informing the reviewer that local edits exist and how to reset them.

#### Live search (Round 5)

- **FR-062**: The search input on Savings Goals MUST live-filter goal cards by name (case-insensitive) as the user types.
- **FR-063**: The search input on Holdings MUST live-filter holding rows by ticker or name (case-insensitive) as the user types.
- **FR-064**: The search input on the Budget transaction ledger and on Business entity transaction ledgers MUST live-filter table rows by any text content (case-insensitive).

---

### Key Entities

**From Round 1:**

- **Prototype navigation structure**: The `NAV` constant in `app.js` — the authoritative array for sidebar structure.
- **Inspector panel**: `<aside class="inspector">` in `index.html` and the `renderInspector` / `select` functions — closed by default, slide-over overlay.
- **Onboarding flow**: First-launch screen covering all seven iCloud workspace states, navigable from Settings.
- **Toolbar sync pill**: `<div class="sync-pill">` — multi-state toolbar element with four distinct visual states.
- **Validation issue card**: Issue row design within the Overview Issues table and in the inspector.
- **Repair preview panel**: Inspector content when a repairable issue is selected — diff-style before/after with Apply/Cancel.
- **Benchmark heat map**: `viewInvestmentsBenchmarks()` — table component with 8 period columns.
- **Budget pie chart**: `viewBudgetOverview()`, using `donutChart` SVG helper.

**Added in Round 5:**

- **`store.js`**: Prototype persistence module. `Store.hydrate()` overlays localStorage onto `DATA`; `Store.save()` serializes 16 mutable collections; `Store.reset()` clears storage and reloads; `Store.isDirty()` detects unsaved local state. Storage key: `finance-proto-workspace-v1`. Loaded between `data.js` and `app.js`.
- **`commit()`**: Stand-in for the TDD §13 structured write flow. Calls `Store.save() → renderSidebar() → renderCenter() → renderInspector()`. Called after every mutation.
- **`openModal(config)`**: Reusable form/dialog builder. Renders a `.modal-overlay` + `.modal` card with fields and optional `body` slot. Handles text/number/date/select/textarea/file. Validates required fields on submit.
- **`toast(message, kind)`**: Transient notification. Appended to `.toast-host` in the lower-right; auto-dismisses. Kinds: `ok` (green), `warn` (amber), `info` (neutral).
- **`openMenu(anchor, options, onPick)`**: Dropdown builder. Positions a `.proto-menu` relative to the clicked anchor; closes on outside click.
- **`exportCSV(filename, headers, rows)`** / **`exportMarkdown(filename, md)`**: Real browser file downloads using `Blob` + `URL.createObjectURL`. `toCSV(headers, rows)` handles RFC 4180 cell escaping.
- **`osAction(label, target)`**: Toast fallback for OS-level operations (Finder reveal, editor open, file download) that a browser cannot perform.
- **`ingestTransactionCSV(text, { entityId, business })`**: Parses `date,merchant,description,category,amount` CSV (header optional) and calls `addTransaction` per row. Returns the count of successfully imported rows.
- **`addTransaction(v)`**: Constructs a canonical transaction object (with generated `id`, `direction`, `source`, `row`, `entityId`, `deductible`) and pushes to `DATA.transactions`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

**From Round 1:**

- **SC-001**: Every open design task listed under Phase 1 and Phase 2 in `docs/product-roadmap.md` is represented by at least one designed prototype screen — none remain undesigned.
- **SC-002**: A reviewer walking through every sidebar section finds zero v2-deferred views (Notes, Issues standalone, Files, Budget Rules, Monthly Snapshots, Annual Snapshots) and no top-level Business section reachable from navigation.
- **SC-003**: Every v1 section (Overview, Accounts, Budget, Savings & Investments, Taxes, Settings) renders without a JavaScript error in the browser console.
- **SC-004**: A reviewer can identify the correct designed treatment for all 7 iCloud workspace states by navigating the onboarding flow — no state is missing or shown as a placeholder text block.
- **SC-005**: A reviewer can walk through the full single-issue repair flow — select an issue, read the diff preview, click Apply — without leaving the prototype.
- **SC-006**: A reviewer opening the prototype on a fresh load observes the right panel is not visible anywhere before they make a selection.
- **SC-007**: Any engineer starting Phase 1 or Phase 2 development can answer their open design questions by opening the prototype — no design decisions in those phases remain unresolved in the prototype.

**Added in Round 5:**

- **SC-008**: A reviewer adds a savings goal, reloads the page, and the goal still appears with the correct sidebar badge count — demonstrating localStorage persistence.
- **SC-009**: A reviewer imports a CSV file on the Budget screen and sees the imported rows appear in the ledger immediately. After a page refresh, the rows are still present.
- **SC-010**: A reviewer clicks every Export button in the prototype and receives a file download in each case — no Export button produces a toast error or no response on a non-empty dataset.
- **SC-011**: A reviewer applies a repair to every repairable issue individually or via "Apply repairable fixes" and the issue count in the toolbar reaches zero.
- **SC-012**: A reviewer clicks "Reset prototype data" in Settings, confirms the dialog, and is returned to the prototype in seed state — the Savings Goals sidebar badge returns to its seed value and any previously added goals are gone.
- **SC-013**: A jsdom smoke test (or equivalent headless harness) loads the full prototype, exercises add-goal, apply-repair, checklist-toggle, transaction-import, CSV-export, and filter-menu flows, and asserts correct outcomes — all assertions pass.

---

## Assumptions

### Still true

- All prototype changes are confined to `prototype/` (`app.js`, `index.html`, `styles.css`, `data.js`, `store.js`). No other project files are created or modified for prototype purposes.
- The existing chart helpers (`donutChart`, `lineChart`, `barChart`) and the `el()` DOM utility are available for all view functions without modification.
- The repair preview "diff" does not need to be a true computed diff — hardcoded before/after row text that communicates the visual pattern is sufficient for prototype purposes.
- Modal accessibility (Esc-to-close, focus trapping, ARIA roles) is deferred — acceptable for the prototype but must be addressed in the Swift dialog implementation.
- The dataset covers a single month (May 2026). Period filters and trailing-average columns are interactive but cannot be fully data-driven until multi-month data is added.

### Retired from Round 1 (no longer true)

- ~~"Mock and placeholder data is acceptable throughout. Data accuracy is not a goal — visual design fidelity and interaction pattern clarity are."~~ — The prototype is now an **interactive** prototype. Flows must produce real state changes that persist. Data accuracy within the seed set is still approximate (single month, illustrative amounts), but interactions (create, import, export, repair) must be functionally correct.
- ~~"All changes are confined to `prototype/` (`app.js`, `index.html`, `styles.css`, `data.js`). No other files are created."~~ — `prototype/store.js` was added in Round 5 as a required fifth file.

### Prototype-specific decisions (not for project-level docs)

These implementation choices are specific to the browser prototype and should not be reflected in `docs/product-requirements.md` or `docs/technical-design.md`:

- **Storage key**: `finance-proto-workspace-v1` in `localStorage` — browser analogue for iCloud file writes.
- **Seed vs. saved state**: `data.js` is the canonical seed (template state); user edits layer on top via `Store.save()` and survive refresh. `Store.reset()` restores the seed — analogous to restoring from a backup in the native app.
- **`commit()` as write-flow stand-in**: The Swift app uses a full structured write flow (build plan → preview → backup → atomic write → re-index). The prototype approximates this with `commit()` = persist → re-render. The shape of the write flow is correct; the preview and backup steps are shown in the repair inspector, not replicated for every create action.
- **`osAction()` for native affordances**: Finder reveal, editor open, and OS file downloads are mocked as toasts rather than actual system calls — the prototype runs in a browser. This is a known gap acknowledged to reviewers via the toast message.
- **Export column choices**: The CSV column sets defined in FR-050–057 represent the intended export shape for the v1 app. They are specified here (not in the PRD) because they were determined during prototype implementation and need design review before being locked in the Swift spec.
- **Markdown packet formats**: The business P&L and tax prep packet Markdown structures defined in FR-058–059 are the intended output formats for the v1 export features. They are specified here for the same reason.
