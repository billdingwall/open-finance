# Feature Specification: Prototype as Design Source of Truth

**Feature Branch**: `001-prototype-prd-alignment`
**Created**: 2026-06-08
**Last updated**: 2026-06-14 (Round 5 — interactive prototype pass + spec corrections)
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

See `prototype/README.md` for the review process: how to run a session, how to reset data,
how to update this spec, and which items are deferred.

---

## Round History

| Round | Date | Summary |
|---|---|---|
| Round 1 (r1) | 2026-06-08 | Initial alignment spec: navigation restructure, merged modules, updated views. Scope: visual fidelity only. |
| Round 5 (r5) | 2026-06-14 | Interactive pass: localStorage persistence layer, create/import/export/repair/checklist flows, live search, filter menus, OS-action toasts, Settings reset control. Spec corrections: deductions inline (not sidebar), benchmarks as Holdings toggle (not separate screen), Taxes sidebar corrected to 3 items. |

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
4. **Given** the Savings & Investments section is expanded, **When** the reviewer reads sub-items, **Then** Goals and Portfolio sub-views (Portfolio Overview, Holdings) are accessible within one section.
5. **Given** no section is selected, **When** the prototype loads, **Then** the prototype defaults to the Accounts screen, and the right inspector panel is not visible.
6. **Given** the reviewer inspects the toolbar, **When** they read left to right, **Then** they can see a workspace identifier, a sync status indicator, and an issue count indicator — the same persistent elements that will appear in the macOS toolbar.

---

### User Story 2 - Right Detail Panel as Slide-Over (Priority: P2)

A reviewer selects a row or KPI card in any module and the right inspector panel appears as a
slide-over from the right edge. The main content does not shift or shrink. The panel closes
when the reviewer clicks outside it or navigates away. The panel is never open by default on
any section or navigation change.

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

A designer opens the prototype and can walk through a first-launch experience covering all
seven iCloud workspace states plus the workspace-creation success state. Recovery actions
on each state are wired — "Start using app" navigates to Accounts; other OS-level actions
display an honest toast explaining they would be triggered by the native macOS app.

**Independent Test**: Navigate to Settings › Workspace and click "Show onboarding flow". Confirm
all seven iCloud states are shown plus the success state. Confirm every recovery action button
responds (navigation or toast).

**Acceptance Scenarios**:

1. **Given** the reviewer opens the onboarding screen, **When** they view each iCloud state card, **Then** the following seven states appear: Available, Not signed in, Container unavailable, Syncing, Local copy stale, File missing locally, Conflict detected.
2. **Given** the reviewer views the "Not signed in to iCloud" state, **When** they read the screen, **Then** a clear explanation and a call-to-action to sign in or use a local fallback is shown.
3. **Given** the reviewer views the "Conflict detected" state, **When** they read the screen, **Then** the conflict is described clearly with a resolution path (not just a generic error).
4. **Given** workspace creation completes successfully, **When** the reviewer views the success state, **Then** the workspace path, workspace ID, and a "Start using app" action are shown — clicking "Start using app" navigates to the Accounts screen.
5. **Given** the reviewer clicks any other recovery action (Open iCloud Settings, Retry, Download now, etc.), **When** the action fires, **Then** a toast appears confirming the action would be triggered by the native macOS app.

---

### User Story 4 - Workspace Sync Status and Indexing States (Priority: P4)

A reviewer can see how the app communicates ongoing workspace status: the persistent sync
pill in the toolbar (four states), per-file sync badges on file path chips, and the indexing
progress screen showing file count, progress bar, and classification warnings.

**Independent Test**: Click "Cycle sync state" in Settings › Workspace to step through synced /
syncing / stale / error. Inspect a file path chip in any inspector. Navigate to "Show indexing
state" and confirm a progress bar and classification warnings table appear.

**Acceptance Scenarios**:

1. **Given** the reviewer cycles the sync state, **When** they step through all four, **Then** the sync pill shows four visually distinct states: synced (green), syncing (animated), stale (amber), error (red).
2. **Given** the reviewer inspects a file path chip in any detail or inspector view, **When** they look for a sync badge, **Then** four per-file sync states are visually distinct: available locally, syncing, missing locally, conflict.
3. **Given** the reviewer navigates to the indexing state screen, **When** the view loads, **Then** a file count, a progress bar, and a classification warnings table are shown — not a blank screen or spinner alone.

---

### User Story 5 - Validation Issue Card and Repair Preview Panel (Priority: P5)

A reviewer can see the designed treatment for validation issues and repair flows. Individual
repair and bulk repair are both exercisable. Clicking "Apply repair" in the inspector removes
the issue, decrements the count, and persists. Clicking "Apply repairable fixes" on Overview
bulk-repairs all auto-repairable issues.

**Independent Test**: Open the Overview Issues table. Select a repairable issue — confirm the
inspector shows a before/after diff, backup note, and Apply button. Click Apply — confirm the
issue disappears and the count decrements. Click "Apply repairable fixes" — confirm all
remaining repairable issues are removed at once.

**Acceptance Scenarios**:

1. **Given** the reviewer views the Overview Issues table, **When** they read an issue row, **Then** each row shows: a severity indicator (color + icon), affected file path, short description, and a repairable/manual badge.
2. **Given** the reviewer views issues of different severities, **Then** all three severity indicators (error, warning, info) are visually distinct — color and icon all differ.
3. **Given** the reviewer selects a repairable issue, **When** the inspector opens, **Then** a before/after diff panel, a backup confirmation note, and Apply / Cancel buttons are present.
4. **Given** the reviewer clicks Apply repair in the inspector, **When** the action completes, **Then** the issue is removed from the table, the toolbar count decrements, a toast confirms "backup saved", and the change persists after a page refresh.
5. **Given** the reviewer selects a manual-only issue, **When** the inspector opens, **Then** no diff panel or Apply button is shown — only an explanation and Reveal in Finder / Open in Editor actions.
6. **Given** the reviewer clicks "Apply repairable fixes" on Overview, **When** the action completes, **Then** all auto-repairable issues are removed, a toast confirms how many were repaired and that backups were saved, and the change persists.

---

### User Story 6 - Overview Dashboard (Priority: P6)

A reviewer navigates to Overview and sees the updated dashboard: no filter bar, exactly five
KPI cards, a month-over-month trend panel, and an inline Issues table. Each KPI card
navigates to its corresponding module.

**Acceptance Scenarios**:

1. **Given** the reviewer is on Overview, **When** they look above the KPI grid, **Then** no filter bar is present.
2. **Given** the Overview is shown, **When** the reviewer counts the KPI cards, **Then** exactly five appear: Budget, Savings, Investments, Business NI (Consulting LLC), Taxes.
3. **Given** the Overview is shown, **When** the reviewer scrolls down, **Then** an Issues table is present showing validation issues grouped by severity with repairable badges.
4. **Given** the reviewer clicks a KPI card, **When** navigation occurs, **Then** they land on the corresponding module view (Business NI navigates to the Consulting LLC entity under Accounts).

---

### User Story 7 - Budget Module (Priority: P7)

A reviewer navigates to Budget and sees the pie chart overview, the trailing average column,
and the absence of Rules. They can import transactions from a CSV file or enter one manually,
add new categories, and export the ledger or category list.

**Acceptance Scenarios**:

1. **Given** the reviewer opens Budget, **When** the overview loads, **Then** a pie or donut chart shows fixed expenses, discretionary, savings, and investments as percentages of monthly net income.
2. **Given** the reviewer views the category variance table, **When** they read column headers, **Then** a 3-month trailing average column is present alongside planned, actual, and variance.
3. **Given** fewer than 3 months of data exist, **When** the trailing average is shown, **Then** it displays a partial value with a visual cue — not blank or zero.
4. **Given** the reviewer searches for Budget Rules, **When** they look thoroughly, **Then** no Rules entry, link, or view is accessible anywhere.
5. **Given** the reviewer clicks "Import CSV", **When** the modal opens, **Then** a file upload section shows the accepted format (`date, merchant, description, category, amount`) and a manual-entry form is present as a fallback.
6. **Given** the reviewer clicks "New category" and completes the form, **When** the modal closes, **Then** the new category row appears and the change persists after a page refresh.

---

### User Story 8 - Savings & Investments Unified Module (Priority: P8)

A reviewer finds Savings & Investments as a single merged section. Goals and Portfolio are
sub-views within it. The benchmark heat map is a view toggle on the Holdings screen, not a
separate screen. The reviewer can add a savings goal and see it appear immediately.

**Acceptance Scenarios**:

1. **Given** the reviewer inspects the sidebar, **When** they look for Savings Goals and Investments as separate items, **Then** neither exists — only Savings & Investments appears.
2. **Given** the reviewer opens Savings & Investments, **When** they navigate within it, **Then** both goal cards and portfolio holdings are accessible from the same section.
3. **Given** the reviewer is on the Holdings screen, **When** they click the heat map toggle button, **Then** the table switches to a benchmark heat map with exactly 8 period columns: D, W, M, 3M, 6M, 1Y, 3Y, 5Y. Clicking the toggle again restores the standard holdings table. Toggle state is stored in `state.holdingsMode` and resets to `'standard'` on page reload.
4. **Given** the reviewer is in heat map mode, **When** they locate an account row and a time period cell, **Then** the cell shows a % growth value (or a dash for unavailable data) — not a chart shape.
5. **Given** the reviewer clicks "New goal" and completes the form, **When** the modal is submitted, **Then** the new goal card appears in the Goals view, the sidebar goals badge increments, and the goal persists after a page refresh.

---

### User Story 9 - Taxes and Accounts (Priority: P9)

A reviewer finds the Taxes section with exactly three sub-views: Current Tax Year (which
embeds estimated payments, gains & income, and deduction groups inline), Prep Checklist
(full-width focal screen with interactive checkboxes), and Tax Archive (read-only list of
closed years). The Accounts section shows individual account cards grouped by entity theme,
with each entity navigable to a dedicated dashboard.

**Independent Test**: Expand Taxes — confirm exactly three items. Open Current Tax Year and
scroll to confirm deduction groups appear inline below the payments and gains panels. Check a
checklist item on Prep Checklist — confirm it persists after reload. Navigate to a business
entity in the sidebar — confirm a tab bar with Dashboard / Transactions / Budgets / Categories.

**Acceptance Scenarios**:

1. **Given** the reviewer expands Taxes, **When** they read sub-items, **Then** exactly three items appear in order: Current Tax Year, Prep Checklist, Tax Archive. Deductions, Estimated Payments, and Gains & Income do not appear as separate sidebar items — their content surfaces inline on Current Tax Year.
2. **Given** the reviewer opens Current Tax Year and scrolls past the estimated payments and gains/income panels, **When** they reach the bottom of the screen, **Then** four labeled deduction groups appear inline: Standard Deduction, Above-the-Line Deductions, Schedule A — Itemized Deductions, Schedule C — Self-Employment Deductions. Each group shows a per-line deduction table with estimated amount and status.
3. **Given** the reviewer opens Current Tax Year, **When** the view loads, **Then** a KPI grid and per-account effective rate table (taxable income / taxes paid / taxes owed / effective rate) are shown.
4. **Given** the reviewer clicks a checklist item on the Tax Prep Checklist, **When** the click registers, **Then** the checkbox toggles immediately and the state persists after a page refresh.
5. **Given** the reviewer clicks "Export prep packet", **When** the action completes, **Then** a Markdown file downloads with the prep checklist (GFM task list), estimated payments table, and deductions table.
6. **Given** the reviewer navigates to Accounts, **When** the view loads, **Then** an aggregate header (Monthly Inflow, YTD Net Income, Accounts count) and account cards grouped under theme headings (Personal Assets, Place of Employment, Business Entities) appear. Each card shows account name, institution, group label, monthly inflow, and YTD net income. Clicking a card opens the inspector.
7. **Given** the reviewer clicks a business entity name in the sidebar under Accounts, **When** the entity dashboard opens, **Then** a tab bar provides Dashboard, Transactions, Budgets, and Categories — and Import CSV and Export P&L actions are available.

---

### User Story 10 - Prototype Persistence and Reset (Priority: P1, Round 5)

A reviewer makes changes during a review session and returns after closing the browser tab —
all changes persist. In Settings, a "Reset prototype data" control returns the prototype to
its seed state.

**Acceptance Scenarios**:

1. **Given** a reviewer adds a goal and closes the browser tab, **When** they reopen the prototype, **Then** the added goal is still present.
2. **Given** a reviewer imports a transaction and reloads the page, **When** the page loads, **Then** the imported transaction still appears in the ledger.
3. **Given** a reviewer applies a repair and reloads, **When** the page loads, **Then** the issue count reflects the repaired state.
4. **Given** the reviewer has made changes, **When** they open Settings › Workspace, **Then** a note says their local edits are saved to this browser and describes how to reset them.
5. **Given** the reviewer clicks "Reset prototype data" and confirms the dialog, **When** the reset completes, **Then** the prototype reloads in seed state with all edits gone.
6. **Given** the reviewer clicks "Reset prototype data" and cancels the confirmation, **When** they return to Settings, **Then** no data has been changed.

---

### User Story 11 - Create Flows for Core Entities (Priority: P1, Round 5)

A reviewer can create new instances of every major entity type. Each create flow opens a
modal, validates required fields, and commits the new item on submit.

**Acceptance Scenarios**:

1. **Given** the reviewer submits a create form with an empty required field, **Then** a field-level error appears on that input and the modal does NOT close.
2. **Given** the reviewer fills all required fields and submits a New Goal form, **When** the modal closes, **Then** the new goal card appears immediately with correct values.
3. **Given** the reviewer clicks "New entity" with type "business", **When** the modal closes, **Then** the new entity appears in the Business Entities section of Accounts and in the sidebar under Accounts.
4. **Given** the reviewer clicks "New payment" in Taxes, **When** the form is submitted, **Then** the new payment appears in the payments table with status "pending".

---

### User Story 12 - Transaction CSV Import (Priority: P1, Round 5)

A reviewer can import transactions into Budget or a Business entity's ledger by uploading a
CSV file. The modal documents the expected column format. A manual single-entry fallback is
also available in the same modal.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks "Import CSV", **When** the modal opens, **Then** a file upload input for `.csv` files and a format hint (`date, merchant, description, category, amount`) are visible above the manual-entry form.
2. **Given** the reviewer uploads a valid CSV, **When** the file is processed, **Then** all parseable rows are added to the ledger, a success toast shows the row count, and the modal closes.
3. **Given** the reviewer uploads a CSV with no valid rows, **When** the file is processed, **Then** a warning toast says "No valid rows found in [filename]" and the modal stays open.
4. **Given** the reviewer submits with neither a file nor a merchant+amount, **Then** a warning toast instructs them to choose a file or enter a merchant and amount — the modal stays open.

---

### User Story 13 - Export Flows (Priority: P2, Round 5)

A reviewer can click any Export button and receive a real file download. CSV exports contain
live data from the current session. Markdown exports (Business P&L, Tax Prep Packet) produce
structured documents whose formats can be reviewed.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks Export on any view with data, **When** the download occurs, **Then** the file contains current session state — any added/imported items are included.
2. **Given** no rows exist to export, **When** the reviewer clicks Export, **Then** a warning toast says "Nothing to export" and no download is triggered.
3. **Given** the reviewer downloads a business P&L Markdown file, **When** they open it, **Then** it contains a Revenue / Expenses / Net income summary table and a Transactions table with columns: Date, Merchant, Category, Amount, Deductible.
4. **Given** the reviewer downloads the tax prep packet, **When** they open it, **Then** it contains a GFM task list for the prep checklist, an Estimated Payments table, and a Deductions table.

---

### User Story 14 - Filter Menus and Live Search (Priority: P2, Round 5)

Filter bar chips open dropdown menus when clicked. Search inputs on Goals, Holdings, and
transaction ledgers live-filter displayed rows as the reviewer types.

**Acceptance Scenarios**:

1. **Given** the reviewer clicks a filter chip with predefined options, **When** the dropdown opens, **Then** options are listed and selecting one dismisses the menu.
2. **Given** a filter chip has no predefined options, **When** the reviewer clicks it, **Then** a toast informs them the filter is not yet data-driven.
3. **Given** the reviewer types in the Savings Goals search input, **When** they type, **Then** only goal cards whose name matches are shown; clearing the input restores all cards.
4. **Given** the reviewer types in the Holdings or transaction ledger search input, **When** they type, **Then** only matching rows are shown.

---

### Edge Cases

- **Empty state for Accounts**: no accounts → labeled empty state with "Add account" button, not a blank screen.
- **Budget pie chart with all-zero data**: empty state chart with a message, not a broken chart.
- **Heat map cell with missing data**: show a dash (—), not a blank cell or error.
- **Trailing average with < 3 months data**: partial average with a visual cue, not zero or blank.
- **Repairable issue selected**: inspector shows diff + Apply. Manual-only issue: no Apply button — ever.
- **Inspector open when navigating**: panel MUST close and selection MUST clear on every navigation change.
- **iCloud unavailable on first launch**: show the "Container unavailable" state with a recovery action — never show a blank shell.
- **Modal submit with empty required field**: show `field-error` styling, do NOT close the modal or mutate DATA.
- **CSV import with no valid rows**: show a `warn` toast, keep the modal open, do NOT call `commit()`.
- **Export when the collection is empty**: show a `warn` toast, do NOT trigger a download.
- **Bulk repair when no repairable issues remain**: show an `info` toast, do not mutate DATA.
- **"Reset prototype data" clicked**: confirmation modal MUST appear before `Store.reset()` is called.
- **Deduction table rows**: clicking a deduction row does NOT open the inspector — deduction rows are read-only and there is no `deduction` inspector kind.
- **Entity tab state**: the active tab within an entity dashboard resets to "dashboard" on page reload — tab state is session-only (`state.entityTabs`), not persisted to localStorage.

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

- **FR-007**: A first-launch / onboarding screen MUST be reachable from Settings › Workspace ("Show onboarding flow" button) and MUST show all seven iCloud workspace states: Available, Not signed in, Container unavailable, Syncing, Local copy stale, File missing locally, Conflict detected.
- **FR-008**: Each iCloud state card MUST show a distinct visual treatment: at minimum a title, a description, and where appropriate a recovery action button.
- **FR-009**: The workspace-creation success state MUST show workspace path, workspace ID, and a "Start using app" action. Clicking "Start using app" MUST navigate to the Accounts screen.

#### Sync status and indexing (Round 1)

- **FR-010**: The toolbar sync pill MUST display four visually distinct states: synced, syncing, stale, and error — using distinct colors and/or icons for each.
- **FR-011**: File path chips and file references in detail/inspector views MUST support four per-file sync badge states: available locally, syncing, missing locally, conflict.
- **FR-012**: A loading/indexing state MUST be reachable from Settings › Workspace ("Show indexing state" button) and MUST show: file count scanned, a progress bar, and a classification warnings table — not a generic spinner alone.

#### Validation issue card and repair preview (Round 1 + Round 5)

- **FR-013**: The Overview Issues table rows MUST each show: severity indicator (color + icon), affected file path, short description, repairable/manual badge.
- **FR-014**: Error, warning, and info severity MUST be visually distinct from each other.
- **FR-015**: Selecting a repairable issue in the inspector MUST show a before/after diff panel, a backup confirmation note, and Apply / Cancel actions.
- **FR-016**: Selecting a manual-only issue in the inspector MUST show an explanation and Reveal in Finder / Open in Editor actions — no Apply button.

#### Overview (Round 1)

- **FR-017**: The Overview view MUST NOT render a filter bar.
- **FR-018**: The Overview KPI grid MUST contain exactly five cards: Budget, Savings, Investments, Business (Consulting LLC → `accounts-entity-consulting-llc`), Taxes.

#### Budget (Round 1)

- **FR-019**: The Budget Overview MUST include a pie or donut chart showing spending breakdown as a percentage of monthly net income.
- **FR-020**: The category variance table MUST include a 3-month trailing average column.

#### Savings & Investments — holdings toggle (Round 1, corrected Round 5)

- **FR-021**: *(Number reserved — not used in Round 1. See FR-022.)*
- **FR-022**: The Holdings screen MUST provide a view toggle between a standard holdings table and a benchmark heat map. In heat map mode the table MUST show columns for D, W, M, 3M, 6M, 1Y, 3Y, 5Y — one row per investment account plus an S&P 500 row. Toggle state is stored in `state.holdingsMode` (`'standard'` | `'heatmap'`) and is NOT persisted to localStorage.

#### Taxes (Round 1, corrected Round 5)

- **FR-023**: Deduction groups MUST render inline within the Current Tax Year screen, appended after the estimated payments and gains/income panels (via `appendDeductionGroups(c)`). Four labeled groups MUST appear: Standard Deduction, Above-the-Line Deductions, Schedule A — Itemized Deductions, Schedule C — Self-Employment Deductions. Each group shows a per-line table with `Deduction`, `Estimated Amount`, and `Status` columns plus a totals row. **Deduction rows are read-only — clicking one does NOT open the inspector. There is no `deduction` inspector kind.**
- **FR-024**: The Current Tax Year view MUST include a per-account effective rate table showing: taxable income, taxes paid, taxes owed, and effective rate per account.

#### Accounts (Round 1, expanded Round 5)

- **FR-025**: The Accounts overview MUST render an aggregate header (Monthly Inflow, YTD Net Income, active Accounts count) and account cards grouped under three theme headings: Personal Assets, Place of Employment, Business Entities. Cards are individual account records (from `DATA.accounts`), not entity records. Clicking a card opens the `account` inspector kind.

---

#### Persistence layer (Round 5)

- **FR-026**: A `store.js` module MUST implement the prototype persistence layer. It MUST expose: `hydrate()`, `save()`, `reset()`, `isDirty()`, and `syncDerived()`. Loaded between `data.js` and `app.js` in `index.html`.
- **FR-027**: `Store.hydrate()` MUST read from `localStorage` key `finance-proto-workspace-v1`. If saved data exists, it overlays the following 16 collections onto the seed `DATA`: `goals, transactions, categories, rules, accounts, entities, estimatedPayments, deductions, taxChecklist, issues, holdings, sleeves, sleeveTargets, notes, businessCategories, businessBudgets`. After overlay, `syncDerived()` MUST recompute `DATA.businessTransactions = DATA.transactions.filter(t => /^BX-/.test(t.id))`.
- **FR-028**: `Store.save()` MUST serialize the same 16 collections to localStorage and call `syncDerived()` before writing.
- **FR-029**: `Store.reset()` MUST call `localStorage.removeItem(key)` then `location.reload()`.
- **FR-030**: Every mutation to `DATA` in the prototype MUST go through `commit()`. `commit()` MUST call `Store.save()`, then re-render sidebar, center, and inspector in that order.

#### Interaction infrastructure (Round 5)

- **FR-031**: A reusable `openModal({ title, subtitle, fields, body, submitLabel, cancelLabel, onSubmit })` function MUST be implemented. Fields support types: `text`, `number`, `date`, `select`, `textarea`. A `file` upload section is supported via `body`. Required fields MUST show `field-error` styling and block submit if empty. `onSubmit` returns `true` to close the modal or `false` to keep it open.
- **FR-032**: A `toast(message, kind)` function MUST show a transient notification anchored to the bottom-right of the viewport. Kind `ok` = green, `warn` = amber, `info` = neutral.
- **FR-033**: An `openMenu(anchor, options, onPick)` function MUST show a positioned `.proto-menu` dropdown relative to the trigger element, closing on outside click.
- **FR-034**: Filter bar chips that have an `options` array MUST call `openMenu` on click. Chips without options MUST show a `toast` fallback.
- **FR-035**: Buttons that invoke OS-level actions (Reveal in Finder, Open in editor, Download in indexing screen) MUST call `osAction(label, target)`, which shows a `toast`. They MUST NOT show a broken or empty state.

#### Create flows (Round 5)

- **FR-036**: `New goal` → modal: Name (text, required), Target amount (number, required), Monthly target (number), Target date (date). Pushes to `DATA.goals`, updates sidebar badge, calls `commit()`.
- **FR-037**: `Import CSV` / `Import transactions` → modal with a `.csv` file upload section (hint: `date, merchant, description, category, amount`, header optional, negative amounts = expenses) and a manual-entry fallback form (Date, Merchant, Description, Category select, Amount number). CSV file reads via FileReader → `ingestTransactionCSV`. Manual entry calls `addTransaction`. Both call `commit()` on success.
- **FR-038**: `New category` → modal: Name (text, required), Group (select), Planned monthly (number). Pushes to `DATA.categories`, calls `commit()`.
- **FR-039**: `New entity` → modal: Display name (text, required), Type (select: business/employment/personal), Tax ID (text). Pushes to `DATA.entities`, calls `commit()`. New entity appears in the sidebar under Accounts and in the Accounts dashboard.
- **FR-040**: `New account` / `Add account` / `Add Asset` → modal: Name (text, required), Type (select: checking/savings/investment/loan/credit), Institution (text), Balance (number). Pushes to `DATA.accounts`, calls `commit()`.
- **FR-041**: `Import Paystub` (Employment entity) → modal: Pay period (date), Gross pay (number), Net pay (number). Adds a payroll credit transaction to `DATA.transactions`, calls `commit()`.
- **FR-042**: `New payment` (Taxes) → modal: Quarter (select: 1/2/3/4), Year (number), Jurisdiction (select: Federal/State), Due date (date), Amount (number). Pushes to `DATA.estimatedPayments` with `status: 'pending'`, calls `commit()`.
- **FR-043**: `Import prices` (Portfolio/Holdings) → modal: Holding (select from `DATA.holdings` tickers), New price (number, required). Updates the selected holding's `price` field, calls `commit()`.
- **FR-044**: `Rebalance plan` → computed drift-to-trade modal (sleeve actual vs. target weight, showing only |drift| > 0.5%). "Export plan" downloads `rebalance-plan.csv` with columns: `ticker, sleeve, drift, trade_usd`.
- **FR-045**: Business Categories `New` → modal: Name (text, required), Group (text). Pushes to `DATA.businessCategories`, calls `commit()`.

#### Repair and checklist (Round 5)

- **FR-046**: Inspector `Apply repair` → `applyRepair(id)`: removes the issue from `DATA.issues`, decrements `DATA.workspace.issueCount`, closes inspector, toasts "1 issue repaired · backup saved", calls `commit()`.
- **FR-047**: Overview `Apply repairable fixes` → bulk-removes all issues where `repairable === true`, updates `issueCount`, toasts "{n} issues repaired · backups saved", calls `commit()`. If none repairable: shows `info` toast.
- **FR-048**: Tax prep checklist items → click calls `toggleChecklistItem(id)`, flips `done`, calls `commit()`. Visual state updates immediately via re-render.

#### Reindex (Round 5)

- **FR-049**: `Reindex` buttons MUST call `runReindex()`: sets `state.syncState = 'syncing'`, re-renders sidebar, waits ~2 seconds, sets `state.syncState = 'synced'`, re-renders, shows `info` toast.

#### Export shapes (Round 5)

All exports use `exportCSV(filename, headers, rows)` or `exportMarkdown(filename, md)` producing real browser file downloads from live `DATA`.

- **FR-050**: Budget Overview `Export` → `transactions-2026-05.csv` — columns: `date, merchant, description, account, category, amount` (personal non-income transactions only).
- **FR-051**: Budget History `Export` → `budget-history.csv` — columns: `month, planned, actual, variance`.
- **FR-052**: Budget Categories `Export` → `categories.csv` — columns: `id, name, group, planned`.
- **FR-053**: Savings Goals `Export` → `savings-goals.csv` — columns: `name, target, balance, monthly_target, target_date`.
- **FR-054**: Portfolio Overview `Export` → `holdings.csv` — columns: `ticker, name, account, sleeve, qty, price, basis, market_value` (where `market_value = round(qty × price)`).
- **FR-055**: Holdings view `Export` → `holdings.csv` — columns: `ticker, name, account, sleeve, qty, price, basis`.
- **FR-056**: Overview Issues `Export` → `overview-issues.csv` — columns: `severity, group, title, file, repairable`.
- **FR-057**: Rebalance plan `Export plan` → `rebalance-plan.csv` — columns: `ticker, sleeve, drift, trade_usd`.
- **FR-058**: Business / Account Entity `Export P&L` → `{entityId}-pl.md` — Markdown: (1) heading `# {Entity} — P&L (May 2026)`, (2) Revenue / Expenses / Net income summary table, (3) `## Transactions` section with columns `Date, Merchant, Category, Amount, Deductible`.
- **FR-059**: Taxes `Export prep packet` → `2026-tax-prep-packet.md` — Markdown: (1) `## Prep checklist` as GFM task list (`- [x]` / `- [ ]` per item with optional due date), (2) `## Estimated payments` table (`Quarter, Jurisdiction, Due, Amount, Paid, Status`), (3) `## Deductions` table (`Deduction, Type, Estimated, Status`).
- **FR-060**: Accounts Overview `Export` → `accounts.csv` — columns: `name, institution, group, type, entity, monthly_inflow, ytd_net_income` (all records from `DATA.accounts`).

#### Settings (Round 5)

- **FR-061**: Settings › Workspace MUST include a clearly labeled **"Prototype Review Controls"** section with the disclaimer: *"These buttons control prototype state for design review. They do not represent real app functionality."* This section MUST contain four controls: `Show onboarding flow` (navigates to the onboarding screen), `Cycle sync state` (cycles through synced/syncing/stale/error), `Show indexing state` (navigates to the indexing screen), and `Reset prototype data` (danger button, described in FR-062).
- **FR-062**: `Reset prototype data` MUST be styled as `.btn.btn-danger`. Clicking it MUST open a confirmation modal. Only on confirmation MUST `Store.reset()` be called.
- **FR-063**: Settings › Workspace MUST display a live note when `Store.isDirty()` is `true` explaining that local edits exist and describing how to reset them. When `isDirty()` is `false`, the note MUST say the seed dataset is showing.

#### Live search (Round 5)

- **FR-064**: The search input on Savings Goals MUST live-filter goal cards by name (case-insensitive) as the user types.
- **FR-065**: The search input on Holdings MUST live-filter holding rows by ticker or name (case-insensitive) as the user types.
- **FR-066**: The search input on the Budget transaction ledger and on Business entity transaction ledgers MUST live-filter table rows by any text content (case-insensitive).

#### Entity dashboards and tab navigation (Round 5)

- **FR-067**: Business entity dashboards (`viewAccountEntity` with `entity.type === 'business'`) MUST render a four-tab bar: Dashboard, Transactions, Budgets, Categories. Employment entity dashboards MUST render: Dashboard, Transactions. Personal entity dashboards MUST render: Dashboard only. Tab state is stored in `state.entityTabs[entityId]` (session-only — NOT in `PERSIST_KEYS` — resets to `'dashboard'` on page reload).

#### Tax Archive (Round 5)

- **FR-068**: The Tax Archive screen (`viewTaxesArchive`) MUST render a read-only table of prior closed tax years with columns: Tax year, Closed date, Total deductions, Total estimated payments, Archive file path chip. The table is read-only — no edit or delete affordances. The "Close Tax Year" action (locked architectural decision per `technical-design.md §21`) is **deferred** — no button for it exists yet in the prototype.

#### Inspector (Round 5)

- **FR-069**: The `account` inspector kind MUST show: Monthly Inflow (large value), Account details section (Institution, Type, Group, YTD net income), Source section linking to `Accounts/accounts.csv`.
- **FR-070**: The inspector MUST handle exactly the following selection kinds. Unhandled kinds fall to a generic "No detail panel for this selection yet" fallback.

| Kind | Triggered by | Inspector shows |
|---|---|---|
| `transaction` | Click a row in the Budget or Business transaction ledger | Amount (large), Details (date/account/category/direction/recurring/linked goal), Source (file/row/importedFrom), Validation (schema note) |
| `category` | Click a category row in Budget Categories | Actual/Planned (large), Variance section (variance/transactions/pacing), Source |
| `rule` | Click a rule row (if surfaced) | Rule details (category/cadence/amount/last applied), Source |
| `goal` | Click a savings goal card | Balance (large), Progress bar with target date, Funding section (monthly target/may funded/source account/linked note), Source |
| `holding` | Click a holding row | Market value (large), Position (account/sleeve/qty/price/basis/unrealized/asset class/sector), Tax lots (NVDA only — hardcoded), Source |
| `sleeve` | Click a sleeve row | Targets (benchmark/monthly contribution/drift policy), Source |
| `biz-tx` | Click a business transaction row | Amount (large), Details (date/entity/category/tax group/deductible), Source |
| `issue` | Click an issue row | Issue (severity/group/file/row/repairable), then: diff panel + Apply/Cancel (repairable) or explanation + Reveal/Open (manual) |
| `note` | Click a note row | Front matter key-value pairs, Source, Linked entities |
| `account` | Click an account card in Accounts | Monthly Inflow (large), Account details (institution/type/group/YTD net income), Source |
| `estimatedPayment` | Click an estimated payment row | Payment details (due/amount/paid/paid date/status), Source |
| `realized` | Click a realized gain row | Lot details (closed/proceeds/basis/gain), Source |
| `overview-kpi` | Click a KPI card on Overview | Calculation (formula/window/last computed), Source files |

#### Legacy URL routing (Round 5)

- **FR-071**: `renderCenter()` MUST handle legacy view IDs from removed or renamed screens by silently redirecting to their current parent. Required redirects:

| Legacy view ID(s) | Redirects to |
|---|---|
| `savings-goals-active`, `savings-goals-archived` | `savings-goals` |
| `investments-accounts`, `investments-sleeves`, `savings-accounts` | `investments-portfolio` |
| `investments-benchmarks`, `investments-benchmark` | `investments-holdings` |
| `business-entity`, `business-all-entities`, `business-monthly` | `viewBusiness()` |
| `taxes-deductions`, `taxes-estimated`, `taxes-gains`, `taxes-estimated-payments`, `taxes-gains-income` | `taxes-current` |

#### V2 stub functions (Round 5)

- **FR-072**: `viewNotes()`, `viewIssues()`, and `viewBudgetRules()` MUST remain as unreachable stub functions in `app.js` — they are NOT included in the `NAV` array. The two search inputs in `viewNotes` and `viewIssues` intentionally use `onChange: () => {}` no-ops and MUST NOT be wired until those views are promoted to V2 navigation.

---

### Key Entities

**From Round 1:**

- **`NAV` constant** in `app.js` — authoritative array for sidebar structure.
- **Inspector panel** — `<aside class="inspector">` in `index.html` + `renderInspector()` / `openInspector()` / `closeInspector()`. Closed by default, slide-over overlay.
- **Toolbar sync pill** — `<div class="sync-pill">` — multi-state element with four distinct visual states, cycled via Settings.
- **`donutChart` / `lineChart` / `barChart`** SVG helpers — used by all chart surfaces.

**Added in Round 5:**

- **`store.js`** — Prototype persistence module. Storage key: `finance-proto-workspace-v1`. Exposes `hydrate()`, `save()`, `reset()`, `isDirty()`, `syncDerived()`. Loaded between `data.js` and `app.js`.
- **`commit()`** — Stand-in for the TDD §13 structured write flow: `Store.save() → renderSidebar() → renderCenter() → renderInspector()`. Called after every mutation.
- **`openModal(config)`** — Reusable form/dialog builder. Renders `.modal-overlay` + `.modal` with fields and optional `body` slot. Validates required fields on submit.
- **`toast(message, kind)`** — Transient notification appended to `.toast-host`, auto-dismisses. Kinds: `ok` / `warn` / `info`.
- **`openMenu(anchor, options, onPick)`** — Dropdown builder. Positions `.proto-menu` relative to clicked anchor, closes on outside click.
- **`exportCSV(filename, headers, rows)`** / **`exportMarkdown(filename, md)`** — Real browser file downloads via `Blob` + `URL.createObjectURL`. `toCSV(headers, rows)` handles RFC 4180 cell escaping.
- **`osAction(label, target)`** — Toast fallback for OS-level operations (Finder reveal, editor open, file download) that a browser cannot perform.
- **`ingestTransactionCSV(text, { entityId, business })`** — Parses `date,merchant,description,category,amount` CSV (header optional, negative amounts = expenses). Returns imported row count.
- **`addTransaction(v)`** — Constructs a canonical transaction object and pushes to `DATA.transactions`.
- **`appendDeductionGroups(c)`** — Renders four deduction group panels inline into an existing content element. Called at the end of `viewTaxesCurrent()`.
- **`state.holdingsMode`** — `'standard'` | `'heatmap'`. Controls the Holdings screen view toggle. Session-only, not persisted.
- **`state.entityTabs`** — Object keyed by entity ID storing the active tab per entity dashboard. Session-only, not persisted.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

**From Round 1:**

- **SC-001**: Every open design task listed under Phase 1 and Phase 2 in `docs/product-roadmap.md` is represented by at least one designed prototype screen.
- **SC-002**: A reviewer walking through every sidebar section finds zero v2-deferred views (Notes, Issues standalone, Files, Budget Rules, Monthly Snapshots, Annual Snapshots) and no top-level Business section reachable from navigation.
- **SC-003**: Every v1 section (Overview, Accounts, Budget, Savings & Investments, Taxes, Settings) renders without a JavaScript error in the browser console.
- **SC-004**: A reviewer can identify the correct designed treatment for all 7 iCloud workspace states by navigating the onboarding flow.
- **SC-005**: A reviewer can walk through the full single-issue repair flow — select an issue, read the diff preview, click Apply — without leaving the prototype.
- **SC-006**: A reviewer opening the prototype on a fresh load observes the right panel is not visible anywhere before they make a selection.
- **SC-007**: Any engineer starting Phase 1 or Phase 2 development can answer their open design questions by opening the prototype.

**Added in Round 5:**

- **SC-008**: A reviewer adds a savings goal, reloads the page, and the goal still appears with the correct sidebar badge count.
- **SC-009**: A reviewer imports a CSV file on the Budget screen and sees the imported rows appear immediately. After a page refresh, the rows are still present.
- **SC-010**: A reviewer clicks every Export button on a non-empty dataset and receives a file download in each case — no Export button produces a toast error or no response on a populated dataset.
- **SC-011**: A reviewer applies repairs to every repairable issue (individually or via bulk) and the toolbar issue count reaches zero.
- **SC-012**: A reviewer clicks "Reset prototype data", confirms, and is returned to seed state — the Savings Goals sidebar badge returns to its seed value.
- **SC-013**: A jsdom smoke test (or equivalent headless harness) loads the full prototype, exercises add-goal, apply-repair, checklist-toggle, transaction-import, CSV-export, and filter-menu flows, and asserts correct outcomes — all assertions pass.

---

## Known Gaps and Deferred Items

Requirements from `docs/product-requirements.md` or locked decisions from `docs/technical-design.md` that are **not yet implemented** in the prototype. Tracked here so reviewers know what to expect and so the next prototype round has a clear backlog.

### P1 — Highest priority

| Gap | PRD reference | Notes |
|---|---|---|
| Edit and delete flows | PRD §5 "edit of transactions", §6 "category editing", §7 "manage savings goals" | Only create is implemented. Inspector is read-only for all kinds. No Edit or Delete affordance anywhere. |
| Per-account ledger screen | PRD §5 "Show a per-account view: monthly gross income vs expenses/tax, YTD net income" | Clicking an account card opens the inspector only. No full-screen account detail view with a transaction list, import/edit affordances, or income-vs-expense chart. |
| Goal contribution recording | PRD §7 "show monthly progress… link savings goals to budgeted monthly contributions" | New goals created with an empty `contributions` array. No "Record contribution" flow. Progress bar on new goals shows 0%. |
| Designed empty states | — | No designed empty state for: no goals, no holdings, no transactions for a month, no estimated payments, no business entities. With create flows live, a reviewer can reach these states. |

### P2 — Data and filtering

| Gap | PRD / TDD reference | Notes |
|---|---|---|
| Multi-month dataset (≥3 months) | PRD "Data management" NFR; §6 trailing averages | Seed data covers May 2026 only. Period filter chips are interactive but fall back to a toast — actual filtering requires multi-month data. Trailing average columns show approximations. |
| CSV import preview/validation step | TDD §13 "preview target file before write"; §3 "Produce warnings for extra or missing columns" | Current import appends rows directly with no pre-write preview and no column-mismatch warning. |

### P3 — Completeness

| Gap | Reference | Notes |
|---|---|---|
| "Close Tax Year" action | `CLAUDE.md` §Architectural decisions (locked); `TDD §21` | Tax Archive is a read-only stub (one hardcoded 2025 row). The Close Tax Year button and the year-close workflow are not prototyped yet. |
| Account rules surface | PRD §5 "Support account-level rules and estimates" | `DATA.rules` has 7 recurring rules and the `rule` inspector kind exists, but no view surfaces the rules table or a create/edit flow. |
| Investment transaction drill-down | PRD §7 "inspect transactions and tax lots behind each holding" | Tax lots display in the NVDA inspector only (hardcoded `if (h.ticker === 'NVDA')` check). No general transactions-per-holding view. |
| Deduction add/edit/status-change | PRD §8 "track expected deductions" | Deduction tables are read-only inline panels. No add-deduction or status-change flow. |
| Estimated payment mark-paid / edit | PRD §8 | "New payment" adds a payment but there is no mark-paid or edit flow. |

### P4 — Polish

| Gap | Notes |
|---|---|
| Two dead search inputs | `viewNotes()` and `viewIssues()` retain `onChange: () => {}` no-ops. Both views are unreachable from nav; fix when V2 views are promoted to navigation. |
| Modal accessibility | No Esc-to-close, no focus trapping, no ARIA roles. Acceptable for the prototype; must be addressed in the Swift dialog implementation. |
| `tax-kpi` inspector kind | Clicking a KPI card on the Current Tax Year screen emits `select({ kind: 'tax-kpi', … })` but there is no matching handler in `renderInspector()` — it falls to the generic fallback. |

---

## Assumptions

### Still true

- All prototype changes are confined to `prototype/` (`app.js`, `index.html`, `styles.css`, `data.js`, `store.js`). No other project files are created or modified for prototype purposes.
- The existing chart helpers (`donutChart`, `lineChart`, `barChart`) and the `el()` DOM utility are available for all view functions without modification.
- The repair preview "diff" does not need to be a true computed diff — hardcoded before/after row text that communicates the visual pattern is sufficient for prototype purposes.
- Modal accessibility (Esc-to-close, focus trapping, ARIA roles) is deferred — acceptable for the prototype; must be addressed in Swift dialog implementation.
- The dataset covers a single month (May 2026). Period filters and trailing-average columns are interactive but cannot be fully data-driven until multi-month data is added (P2).

### Retired from Round 1 (no longer true)

- ~~"Mock and placeholder data is acceptable throughout. Data accuracy is not a goal."~~ — The prototype is now an **interactive** prototype. Flows must produce real state changes that persist. Data accuracy within the seed set is still approximate, but interactions (create, import, export, repair) must be functionally correct.
- ~~"No other files are created."~~ — `prototype/store.js` was added in Round 5 as a required fifth file.

### Prototype-specific decisions (not for project-level docs)

These implementation choices are specific to the browser prototype and must not be reflected in `docs/product-requirements.md` or `docs/technical-design.md`:

- **Storage key**: `finance-proto-workspace-v1` in `localStorage` — browser analogue for iCloud file writes.
- **Seed vs. saved state**: `data.js` is the canonical seed; user edits layer on top via `Store.save()` and survive refresh. `Store.reset()` restores the seed.
- **`commit()` as write-flow stand-in**: The Swift app uses a full structured write flow (build plan → preview → backup → atomic write → re-index). The prototype approximates this with `commit()` = persist → re-render. The preview and backup steps are shown in the repair inspector for issues, not replicated for every create action.
- **`osAction()` for native affordances**: Finder reveal, editor open, and OS file downloads are mocked as toasts. The prototype runs in a browser.
- **Export column choices**: The CSV column sets defined in FR-050–060 represent the intended export shape for the v1 app. They are specified here (not in the PRD) because they were determined during prototype implementation and need design review before being locked in the Swift spec.
- **Markdown packet formats**: The business P&L and tax prep packet Markdown structures in FR-058–059 are the intended output formats for v1 export features, specified here for the same reason.
