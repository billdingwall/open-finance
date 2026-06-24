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
| Accounts | Income, expense, asset, and liability management per account |
| Budget | Monthly plan-vs-actual, category and group totals |
| Savings & Investments | Savings goals; portfolios, sleeves, and assets; benchmark comparisons |
| Business | Multi-entity income, expenses, and budget variance |
| Taxes | Estimated payments, realized gains, tax-adjustment tracking, prep checklist |

Notes, Issues, and Files views are planned for V2.

---

## Repository structure

```
open-finance/
├── docs/
│   ├── product-requirements.md    # What & why — modules, user scenarios, data model, IA
│   ├── technical-design.md        # How & where — lean overview with links to docs/architecture/
│   ├── product-roadmap.md         # When — phased plan with milestone gates
│   ├── project-management.md      # Tasks — remaining work before the Phase 1 build
│   ├── architecture/              # Full technical specs (extracted from technical-design.md in R7)
│   │   ├── index.md               # Quick-lookup table for the architecture directory
│   │   ├── core-domain.md         # Entities, module layout, service responsibilities
│   │   ├── containers-and-budgets.md  # Workspace structure + all 28 CSV/MD file specs
│   │   ├── rulesets-and-taxes.md  # Validation rules + UI requirements per section
│   │   └── data-pipelines.md      # Read/write/repair flows, scripts, ingestion diagrams
│   ├── _refinement/               # Review rounds and doc update plans (round-first naming)
│   │   ├── r{n}-review.md         # Raw feedback per prototype review round
│   │   └── r{n}-update-{doc}.md   # Formatted doc update plan based on a review
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
Technical architecture overview. Covers the layered system model, iCloud workspace strategy, workspace folder structure summary, and locked architectural decisions (§21). Detailed specs — CSV file definitions, validation rules, service responsibilities, data pipeline diagrams — are in `docs/architecture/` (extracted in Round 7); `technical-design.md` links to those files by section.

### `docs/architecture/`
Full technical specifications in four focused files. See `docs/architecture/index.md` for a quick-lookup guide to which file answers which question (e.g. "where is the transactions CSV spec?" → `containers-and-budgets.md §3.1`).

### `docs/product-roadmap.md`
Phased implementation roadmap with Product/Design/Dev tasks per phase and milestone gates.

### `docs/_refinement/`
Prototype review feedback and the doc update plans synthesized from it.

- `r{n}-review.md` — UX and functionality notes from each prototype review round
- `r{n}-update-{doc}.md` — formatted update plan per target document per round (e.g. `r6-update-product-requirements.md`, `r6-update-technical-design.md`)

### `docs/_notes/`
Loose notes and domain research referenced by the team (e.g. `account-types.md`, `deduction-types.md`, `workflow-overview.md`).

---

## Workspace file structure

The app reads from a Finance folder in iCloud Drive with the following layout:

```
Finance/
├── Workspace.md
├── .finance-meta/          # App-managed metadata (manifest, schemas, backups, logs)
├── Accounts/               # Master registry, account-groups, liabilities, unified transaction ledger
├── Budget/                 # Categories, budgets, allocations
├── Savings/                # Savings goals and progress snapshots
├── Investments/            # Assets, prices, portfolios, sleeves, benchmarks
├── Taxes/                  # Tax-adjustments, estimates, documents, estimated payments, settings, archive
└── Notes/                  # Monthly reviews and strategy notes
```

Personal and business activity share the unified `Accounts/transactions/` ledger (distinguished by `account_group_id` and a `BX-` ID prefix) — there is no separate `Personal/` or `Business/` folder. Full file specifications (required columns, path conventions, validation rules) are in `docs/architecture/containers-and-budgets.md §3`.

---

## Design and review workflow

1. **Prototype review** → add `docs/_refinement/r{n}-review.md` with UX and functionality notes
2. **Domain research** → add named research docs to `docs/_notes/` as questions arise
3. **Update plan** → synthesize review docs into `docs/_refinement/r{n}-update-{doc}.md` per affected document
4. **Apply updates** → apply changes to `docs/product-requirements.md`, then cascade to `docs/technical-design.md` and `docs/product-roadmap.md`, each with a Changelog entry. When spec details (schemas, validation rules, service responsibilities) are affected, update the relevant file in `docs/architecture/` directly. Update `docs/project-management.md` to retire resolved FIX items and add new ones.
5. **Design & prototype** → update `docs/_design/` assets and `prototype/` to reflect the changes, then start the next review round
6. **Feature spec** → use Spec Kit (`/speckit-specify`) to create per-module specs when ready to build
