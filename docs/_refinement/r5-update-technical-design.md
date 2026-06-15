# Technical Design Update Plan — Round 5

Source: `docs/product-requirements.md` (post Round 5 / r5-review.md updates), `docs/_refinement/r5-review.md`
Target: `docs/technical-design.md`
Status: Applied 2026-06-15

---

## Summary

Round 5 is a functional-details pass. Technical impact is concentrated in **§4** (information
architecture and app shell: dashboard-as-default, remove the contextual-filter surface, move the
issues chip into the header, move local-actions onto the title row, entity→group labels), **§16**
(Accounts gains an individual-accounts section and a per-account screen; business screens lose
sub-tabs; budget panels go 50/50; charts become real charts), **§11** (add a charting dependency),
and **§13/§15** (delete is now a first-class write with a delete-with-reference rule). §20 and §23
get small notations.

**No CSV file specs change in Round 5.** The terminology change is UI-only (`entity` → `group`
labels); the underlying schema rename (`entity_id` → `group_id`), group nesting (`parent_group_id`),
the new Budget/Strategy container files, and `asset_kind` are **out of scope for this round** — they
are captured in `docs/_notes/object-model-audit.md` for a future object-model round. This plan must
not pre-apply them.

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | §4 Primary navigation | Significant | Overview removed as nav item; becomes default landing reached via sidebar header ("Finance Dashboard") |
| 2 | §4 Main panel | Significant | Remove "Contextual filters" block (filter bar → V2); move Issue status into the global header chip; move local-actions onto the title row |
| 3 | §4 Sidebar examples | Minor | "Themes / entities" labels → "Account groups"; "Personal Assets" → "Personal Accounts"; "New entity" → "New group" |
| 4 | §11 Stack | Minor | Add Swift Charts as the charting dependency (real charts, not placeholder SVGs) |
| 5 | §13 Write flow | Significant | Add delete as a first-class structured write; UI placement convention for edit/delete |
| 6 | §15 Validation rules | Minor | Add "delete with reference check" rule |
| 7 | §16 Accounts | Significant | Individual-accounts card section on group screens; new per-account screen; remove business sub-tabs (ledger inline below net-income chart) |
| 8 | §16 Budget | Minor | Spend Mix / Spending Variance panels 50/50 |
| 9 | §16 (all sections) | Minor | Note that the per-screen filter bar is removed (V2) |
| 10 | §20 Prototype order | Minor | Note dashboard-default, per-account screen, real charts |
| 11 | §23 Wireframes | Notation | Flag Accounts/shell wireframes for the new screens |

---

## Detailed changes

### §4 Information architecture

**Primary navigation.** Remove **Overview** from the top-level navigation list. Add:

> The Overview dashboard is the **default screen** on launch. It is reached via the sidebar
> header (the workspace title, displayed as "Finance Dashboard"), not a dedicated nav item.

Resulting top-level v1 nav: **Accounts, Budget, Savings & Investments, Taxes, Settings**
(Notes / Issues / Files remain V2).

**Left sidebar structure.** Remove the standalone **Overview** entry. Under **Accounts**, rename
the "Themes / entities" group to **"Account groups"**; relabel "Personal Assets (Personal)" →
"Personal Accounts (Personal)". The local "New entity" action becomes **"New group"**. Keep the
data-driven nested-links pattern (still loaded from `Accounts/entities.csv` — the file name is
unchanged this round).

**Main panel.**
- **Remove the "Contextual filters" block** (period/date/account/entity/sleeve/goal/category/
  severity/search/saved-view selectors). The filter bar is deferred to V2. Add a note: *"Module
  screens have no general filter bar in v1; a screen shows period/account selection inline only
  where it is intrinsic to that screen."*
- **Context header → Issue status:** move the issues count to the **global top header**, rendered
  as a chip immediately left of the sync-status chip (review minor #3). It is global, not per-view.
- **Local actions on the title row:** the local-actions row moves onto the **same line as the page
  title**, right-aligned within the main column (review minor #4). Breadcrumbs/title text unchanged.

### §11 Application architecture — stack

Add **Swift Charts** as the charting dependency. Charts (pie/donut, sparklines, the holdings
heat map, monthly net-income, portfolio) are rendered with Swift Charts in the app and a real
charting library in the prototype — not hand-authored placeholder SVGs (review functionality #3).
The Shared UI components (`PieChartView`, `SparklineView`, `HeatMapTableView`) are implemented on
top of Swift Charts.

### §13 Read, write, and repair flows — delete as a first-class write

Extend the structured write flow so **delete** is supported for every user-addable object
(review functionality #6), alongside add/edit. Add a **UI placement convention**:

- Objects whose detail opens in the **right panel** → edit and delete actions live at the
  **bottom of the right panel**.
- Objects with their **own dedicated screen** (e.g. an individual account) → **edit** is in the
  local screen actions; **delete** is offered inside the edit flow.

All deletes use the existing safe-write machinery (preview, timestamped backup, atomic apply) and
must run the reference check below before applying.

### §15 Validation rules — delete with reference check

Add to cross-file validation / write-side rules:

> **Delete with reference check.** Before deleting a row, resolve inbound references (e.g. an
> account group referenced by accounts; an account referenced by transactions/holdings; a category
> referenced by transactions). The write preview must list referencing rows and block or warn per
> the chosen default. (Default behavior — block vs. cascade-warn vs. reassign — is an open decision
> tracked in `docs/_notes/object-model-audit.md` G7; pick before implementing Phase 6 delete flows.)

### §16 UI requirements by section

**Accounts** — restructure:
- **Card grid** label: "Personal Assets" → "Personal Accounts"; "themes/entities" → "account
  groups" throughout this section.
- **Account-group detail screens** (replaces the sub-tabbed theme dashboards):
  - Show an **individual-accounts card section** (same account card as the all-accounts grid)
    above the transaction ledger (review functionality #4).
  - **Business groups:** remove the dashboard/transactions/budgets sub-tabs. Keep the P&L-style
    summary and the monthly net-income chart; place the **transaction ledger inline below the
    net-income chart** (review functionality #2). Category budgets and linked notes stay on the
    same screen.
  - Employment / Personal groups: same single-screen pattern (no sub-tabs).
- **Per-account detail screen (new, review functionality #5):** individual-account cards are
  clickable and open a dedicated screen scoped to one account, with at minimum a transactions
  table. This promotes the old "per-account detail" bullet into its own screen.
- **Edit/delete:** account groups and accounts honor the §13 placement convention.

**Budget** — set the **Spend Mix** and **Spending Variance** panels to an equal 50/50 split so
neither is cut off (review minor #2).

**All module sections** — remove any implication of a per-screen filter bar (deferred to V2).

### §20 Rapid prototype order

No reordering. Add notes: step 3 (Overview) is the **default landing** surface; step 4 (Accounts)
includes the **individual-accounts section and the per-account screen**, no sub-tabs; charts use
the real charting path; the per-screen filter bar is dropped from v1.

### §23 Wireframes

Flag for new wireframes:

| Wireframe | Issue |
|---|---|
| App shell (`01-app-shell.svg`) | Overview is now the default landing via the header (not a nav item); issues chip moves to the global header; local-actions row moves onto the title line; no contextual filter bar |
| Accounts (new) | Account-group screen with individual-account cards + inline ledger (no sub-tabs); new per-account screen with transactions table; "Account groups" / "Personal Accounts" labels |

---

## Items explicitly NOT changed (deferred to the object-model round)

- §8.14 entities CSV — **no** `entity_id`→`group_id` rename, **no** `parent_group_id` this round
- §8.4 budgets / new Budget container; §8.12 sleeves / new Strategy container — not introduced
- §8.8 holdings — **no** `asset_kind` / `name` column changes this round
- §10 canonical entity list — unchanged (Theme/Entity name retained, UI label is "Account Group")
- §21 locked decisions — no reopening
- All other CSV file specs — unchanged

See `docs/_notes/object-model-audit.md` for the deferred structural work and its open questions.

## Changelog stub (to append to technical-design.md)

```
### Round 5 — 2026-06-15
Source: docs/_refinement/r5-review.md (third prototype review — functional details)

- §4: Overview removed as a nav item — it is the default landing screen reached via the sidebar
  header ("Finance Dashboard"); removed the Contextual filters block (filter bar → V2); issues
  count moved to a global header chip left of sync status; local-actions row moved onto the page
  title line (right-aligned); account labels "themes/entities" → "account groups", "Personal
  Assets" → "Personal Accounts", "New entity" → "New group"
- §11: Added Swift Charts as the charting dependency; charts are real charts, not placeholder SVGs
- §13: Delete is now a first-class structured write for all user-addable objects; added the
  edit/delete UI placement convention (right-panel bottom vs. dedicated-screen edit flow)
- §15: Added a delete-with-reference-check write rule
- §16: Accounts — account-group screens show an individual-accounts card section and (business)
  ledger inline below the net-income chart; sub-tabs removed; new per-account detail screen;
  Budget — Spend Mix / Spending Variance panels set to 50/50; per-screen filter bar removed
- §20/§23: Noted dashboard-default + per-account screen + real charts; flagged app-shell and
  Accounts wireframes
- No CSV file specs changed; deeper object-model work (entity→group rename, nesting, Budget/
  Strategy containers, asset kinds) deferred — see docs/_notes/object-model-audit.md
```
