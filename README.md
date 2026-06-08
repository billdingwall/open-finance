# open-finance

A native macOS personal finance workspace backed by plain CSV and Markdown files in iCloud Drive.

The app is a structured interface over files the user owns — not a database, not a sync service. It parses, validates, and projects finance data into dashboards for budgeting, savings, investments, business accounting, and tax prep.

**Status:** Pre-build — planning and design phase.

---

## What it is

- **File-first:** CSV and Markdown in iCloud Drive are the source of truth. The app reads, validates, and builds views on top of them without hiding data in a proprietary database.
- **macOS native:** SwiftUI with a three-column `NavigationSplitView`, keyboard navigation, and Finder-compatible mental model.
- **Traceable:** every KPI links to a detail view; every detail view links to a source file and row.
- **Safe writes:** structured edits are validated, previewable, and backed up before applying.

---

## Modules (v1)

| Module | Purpose |
|---|---|
| Overview | KPI dashboard across all domains |
| Accounts | Income and expense management per taxable account |
| Budget | Monthly plan-vs-actual, category and group totals |
| Savings & Investments | Savings goals, portfolio holdings, sleeves, benchmark comparisons |
| Business | Multi-entity income, expenses, and budget variance |
| Taxes | Estimated payments, realized gains, deduction tracking, prep checklist |

Notes, Issues, and Files views are planned for V2.

---

## Repository structure

```
open-finance/
├── docs/
│   ├── PRD.md                  # Product requirements — primary direction doc
│   ├── technical design.md     # Architecture, data model, file specs, service design
│   └── _reviews/               # Prototype reviews and domain research
│       ├── round-1.md          # Round 1 prototype UX review
│       ├── Account types.md    # Account taxonomy research
│       ├── Deduction types.md  # Tax deduction taxonomy research
│       └── prd-update-plan.md  # Synthesized PRD change list per review round
├── CLAUDE.md                   # AI assistant context and instructions
└── README.md
```

> As implementation begins, source code will live under a top-level app directory (e.g. `FinanceWorkspace/`). This README will be updated to reflect that structure when it exists.

---

## Key documents

### `docs/PRD.md`
Product requirements document. Defines goals, user stories, functional requirements per module, data model, and information architecture. This is the long-horizon direction doc — it is updated after each prototype review round. See the Changelog section at the bottom of the file for a history of changes.

### `docs/technical design.md`
Technical architecture document. Covers the layered system model (storage → indexing → parsing → domain → projection → presentation), iCloud workspace strategy, workspace folder structure, full CSV and Markdown file specifications, internal data model, module layout, service responsibilities, validation rules, and read/write/repair flows.

### `docs/_reviews/`
Prototype feedback and domain research collected during the design phase.

- `round-N.md` — UX and functionality notes from each prototype review round
- Named research docs (e.g. `Account types.md`) — domain reference material that feeds PRD and design decisions
- `prd-update-plan.md` — synthesized change list applied to the PRD after each review round

---

## Workspace file structure

The app reads from a Finance folder in iCloud Drive with the following layout:

```
Finance/
├── Workspace.md
├── .finance-meta/          # App-managed metadata (manifest, schemas, backups, logs)
├── Personal/               # Personal transactions, categories, budgets
├── Savings/                # Savings goals and progress snapshots
├── Investments/            # Holdings, trades, prices, sleeves, benchmarks
├── Business/               # Business entities, transactions, categories, budgets
├── Taxes/                  # Estimated payments, settings, yearly notes
└── Notes/                  # Monthly reviews and strategy notes
```

Full file specifications (required columns, path conventions, validation rules) are in `docs/technical design.md`.

---

## Design and review workflow

1. **Prototype review** → add `docs/_reviews/round-N.md` with UX and functionality notes
2. **Domain research** → add named research docs to `docs/_reviews/` as questions arise
3. **PRD update** → synthesize review docs into `prd-update-plan.md`, apply changes to `PRD.md`, add a Changelog entry
4. **Feature spec** → use Spec Kit (`/speckit-specify`) to create per-module specs when ready to build
