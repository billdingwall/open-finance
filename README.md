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
│   ├── product-requirements.md    # What & why — modules, user scenarios, data model, IA
│   ├── technical-design.md        # How & where — architecture, CSV specs, service design
│   ├── product-roadmap.md         # When — phased plan with milestone gates
│   ├── project-management.md      # Tasks — remaining work before the Phase 1 build
│   ├── _refinement/               # Review rounds and doc update plans
│   │   ├── review-r{n}.md         # Raw feedback per prototype review round
│   │   └── update-{doc}-r{n}.md   # Formatted doc update plan based on a review
│   ├── _design/                   # Design mocks, icons, images, design system
│   └── _notes/                    # Loose notes and domain research for team reference
├── prototype/                     # Static prototype for reviewing the app experience
├── specs/                         # Feature-level Spec Kit artifacts (NNN-feature-name)
├── .specify/                      # Spec Kit workflow engine, templates, constitution
├── CLAUDE.md                      # AI assistant context and instructions
└── README.md
```

> As implementation begins, source code will live under a top-level app directory (e.g. `FinanceWorkspace/`). This README will be updated to reflect that structure when it exists.

---

## Key documents

### `docs/product-requirements.md`
Product requirements document. Defines goals, user stories, functional requirements per module, data model, and information architecture. This is the long-horizon direction doc — it is updated after each prototype review round. See the Changelog section at the bottom of the file for a history of changes.

### `docs/technical-design.md`
Technical architecture document. Covers the layered system model (storage → indexing → parsing → domain → projection → presentation), iCloud workspace strategy, workspace folder structure, full CSV and Markdown file specifications, internal data model, module layout, service responsibilities, validation rules, and read/write/repair flows.

### `docs/product-roadmap.md`
Phased implementation roadmap with Product/Design/Dev tasks per phase and milestone gates.

### `docs/_refinement/`
Prototype review feedback and the doc update plans synthesized from it.

- `review-r{n}.md` — UX and functionality notes from each prototype review round
- `update-{doc}-r{n}.md` — formatted update plan per target document per round (e.g. `update-product-requirements-r1.md`, `update-technical-design-r1.md`)

### `docs/_notes/`
Loose notes and domain research referenced by the team (e.g. `account-types.md`, `deduction-types.md`, `workflow-overview.md`).

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

Full file specifications (required columns, path conventions, validation rules) are in `docs/technical-design.md`.

---

## Design and review workflow

1. **Prototype review** → add `docs/_refinement/review-r{n}.md` with UX and functionality notes
2. **Domain research** → add named research docs to `docs/_notes/` as questions arise
3. **Update plan** → synthesize review docs into `docs/_refinement/update-{doc}-r{n}.md` per affected document
4. **Apply updates** → apply changes to `docs/product-requirements.md`, then cascade to `docs/technical-design.md` and `docs/product-roadmap.md`, each with a Changelog entry
5. **Design & prototype** → update `docs/_design/` assets and `prototype/` to reflect the changes, then start the next review round
6. **Feature spec** → use Spec Kit (`/speckit-specify`) to create per-module specs when ready to build
