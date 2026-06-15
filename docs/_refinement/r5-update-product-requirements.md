# PRD Update Plan — Round 5

Source review: `docs/_refinement/r5-review.md`
Target: `docs/product-requirements.md`
Status: Applied 2026-06-15

---

## Summary

Round 5 is the third prototype review — a **functional-details pass** for MVP. It does three
things:

1. **Trims one surface**: the contextual filter bar is removed from every screen and deferred
   to V2 (needs more design thought).
2. **Fills in functional gaps**: the Overview dashboard becomes the default landing screen
   (not a nav item); account-group screens gain an individual-accounts section and link to a
   new per-account screen; business-group screens lose their sub-tabs (transactions fold into
   the main screen); placeholder SVG charts are replaced with real charts; and **every object
   that can be added can now also be edited and deleted**.
3. **Minor text/styling**: "Personal Assets" → "Personal Accounts" (and "Add Asset" → "Add
   Account"); the account-facing term "entity" → "group"; plus three layout fixes (issues chip,
   local-actions row, budget panel split) that are prototype/TDD-level, noted here for traceability.

**Scope boundary for this round.** The r5 review also includes a "Notes on system objects"
section (captured in `docs/_notes/object-notes.md`) describing a deeper Budget⇄Strategy object
model. That work was **explicitly deferred** by the review itself ("incomplete… should be
audited further as part of the next review") and is analyzed in
`docs/_notes/object-model-audit.md`. **It is NOT part of Round 5.** This round adopts only the
UI-facing "group" terminology; the file/column rename (`entity_id` → `group_id`), group nesting,
Budget/Strategy container objects, and `asset_kind` are left for a future object-model round.

---

## Section-by-Section Changes

### Scope — In scope / Out of scope for v1

**Changes to PRD:**
- **Out of scope (add):** Contextual filter bar / filter chips on module screens — V2 (needs
  more functionality design). Note that period/account/category selection still exists where a
  screen inherently needs it; what is deferred is the dedicated filter-bar surface.
- **In scope (expand):** Replace the line *"Limited structured editing for low-risk entities"*
  with *"Structured add, edit, and delete for user-addable objects (account groups, accounts,
  transactions, categories, goals, holdings/assets, deductions, etc.), with preview, backup, and
  reference checks on delete."* This generalizes editing into the universal add/edit/delete
  requirement (review functionality #6).
- **In scope (note):** Charts are rendered with a real charting approach (Swift Charts in the
  app), not hand-drawn placeholder graphics (review functionality #3).

---

### Information architecture

The Overview dashboard stops being a sidebar nav item and becomes the default landing surface;
account terminology shifts from "entity" to "group".

**Changes to PRD §Information architecture:**
- Remove **Overview** from the "Recommended primary navigation" list. Add a note: *"The Overview
  dashboard is the default screen shown on launch; it is reached via the workspace/sidebar header
  (titled 'Finance Dashboard') rather than a dedicated nav item."*
- Resulting primary navigation: **Accounts, Budget, Savings & Investments, Taxes, Settings**
  (Notes / Issues / Files remain V2).
- Rename the account-facing organizing term throughout the IA prose from "themes/entities" to
  **"account groups" / "groups"**. (Data-model table keeps the canonical `Theme/Entity` name for
  now — see Data model note below.)
- Add: account groups list individual accounts; each individual account has its own screen
  (see §5).
- Remove any reference to a contextual filter bar in the shell description.

---

### §5 Accounts module

The biggest functional change in this round. Account-group screens are restructured and a new
per-account screen is introduced.

**Changes to PRD §5:**
- **Terminology:** rename "Themes or Entities" → "Account Groups" as the primary user-facing
  organizing structure. Keep "personal / employment / business" as group *types*. In the personal
  context, **"assets" → "accounts"** (e.g. "Personal Assets" group → "Personal Accounts";
  "Add Asset" → "Add Account").
- **Individual accounts on group screens (new, review #4):** on each account-group screen, show a
  section of individual-account cards (the same card used on the all-accounts overview) above the
  transaction ledger.
- **Individual account screen (new, review #5):** individual-account cards (from the all-accounts
  view and from group screens) are clickable and open a dedicated per-account screen scoped to
  that account, with at minimum a transactions table. (This refines the existing "per-account
  view" requirement into its own screen.)
- **Business group screens (review #2):** remove the dashboard/transactions/budgets/transactions
  sub-tabs. The transaction ledger moves onto the main business-group screen, below the monthly
  net-income chart. Keep the P&L summary, category budgets, and linked notes on the same screen.
- **Edit/delete (review #6):** account groups and individual accounts can be edited and deleted,
  not only added (see new universal object-management requirement below).

---

### §6 Budget module

**Changes to PRD §6:**
- No functional change. (The "Spend Mix / Spending variance 50/50" fix in review minor #2 is a
  prototype/TDD layout detail, not a PRD requirement.) Optionally note that the budget overview's
  spend-mix and spending-variance panels are co-equal, not one-dominant.

---

### New functional requirement — Object management (add / edit / delete)

Review functionality #6 is cross-cutting; capture it once as its own functional requirement and
reference it from the module sections.

**Add to PRD §Functional requirements (e.g. new "12. Object management"):**
- Any object the user can add — manually or via import — can also be **edited and deleted** in the
  app: account groups, individual accounts, transactions, categories, savings goals, holdings/
  assets, deductions, account rules, etc.
- **UI placement convention:**
  - Objects whose detail opens in the **right panel**: the edit and delete actions appear at the
    **bottom of that panel**.
  - Objects that have their **own dedicated screen** (e.g. an individual account): **edit** is in
    the local screen navigation/actions, and **delete** is an option within the edit flow.
- All edits/deletes follow the safe-write model: preview, timestamped backup, atomic apply. Delete
  must surface any rows that reference the object before applying (reference check).

---

### Data model

**Changes to PRD §Data model:**
- Keep the canonical entity name `Theme/Entity` for this round, but add a footnote:
  *"User-facing label is 'Account Group'. A model-level rename (`entity_id` → `group_id`) and the
  related Budget/Strategy object work are queued for a future object-model round — see
  `docs/_notes/object-model-audit.md`."*
- No entity is added or removed in Round 5.

---

## Cascade

| Doc | Plan file | Why |
|---|---|---|
| `technical-design.md` | `r5-update-technical-design.md` | §4 IA/app shell (dashboard default, remove filter section, issues chip to header, local-actions placement, entity→group), §11 stack (charts), §13/§15 (edit/delete + delete-with-reference rule), §16 UI (individual accounts section + per-account screen, business sub-tab removal, budget panel split, real charts), §20 order, §23 wireframes |
| `product-roadmap.md` | `r5-update-product-roadmap.md` | Out of scope (filter bar V2); Phase 5 module views (account-group detail view, individual-account view, dashboard-as-default shell, issues chip, charts on Swift Charts, FilterBarView → V2); Phase 6 write flows (delete flows per entity) |
| `.specify/memory/constitution.md` | — | No principle change. Universal edit/delete is an application of Principle 4 (Safe writes) + 7 (Repair when safe), not a new principle |

## Changelog stub (to append to product-requirements.md)

```
### Round 5 — 2026-06-15
Source: docs/_refinement/r5-review.md (third prototype review — functional details)

- Overview dashboard is now the default landing screen (reached via the workspace header), not a
  sidebar nav item
- Contextual filter bar removed from module screens and deferred to V2
- Accounts: account-group screens now show an individual-accounts card section and the (business)
  transaction ledger inline; sub-tabs removed; individual accounts open a dedicated per-account
  screen
- Account-facing terminology changed from "entity" to "group"; "Personal Assets" → "Personal
  Accounts" (and "Add Asset" → "Add Account")
- Universal object management: every user-addable object can also be edited and deleted, with
  preview/backup/reference-check (new functional requirement)
- Charts are rendered with a real charting approach (Swift Charts), not placeholder SVGs
- Deferred (not in this round): deeper Budget⇄Strategy object model, group nesting, file/column
  rename, asset kinds — see docs/_notes/object-model-audit.md for the next round
```

## Prototype / design impact

Flag for workflow step 6 (not done in this plan):
- Remove the filter bar from every prototype screen.
- Overview loads by default; remove the "Overview" sidebar section/link; sidebar header links to
  the dashboard; `ws-name` reads "Finance Dashboard".
- Account-group screens: add individual-account cards above the ledger; remove business sub-tabs;
  move the transaction ledger below the net-income chart.
- New per-account screen with a transactions table; make account cards clickable.
- Replace placeholder SVG charts with a real charting library (overview, account-group, portfolio).
- Add edit/delete affordances per the placement convention.
- Text: "Personal Assets" → "Personal Accounts", "Add Asset" → "Add Account", "New entity" →
  "New group" (and "entity" → "group" throughout account screens).
- Layout: issues chip → top header (left of sync chip); local-actions row → same line as page
  title, right-aligned; budget Spend Mix / Spending Variance panels → 50/50.

---

## Priority order for PRD edits

1. IA (dashboard default, primary-nav list, entity→group)
2. §5 Accounts (individual-accounts section, per-account screen, business sub-tab removal,
   terminology, personal "accounts")
3. New §12 Object management (universal add/edit/delete)
4. Scope lists (filter bar out; editing → add/edit/delete; charts note)
5. Data model footnote (group label + deferral pointer)
6. Changelog entry
