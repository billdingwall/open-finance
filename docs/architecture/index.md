# Architecture Reference Index

`docs/technical-design.md` is the overview document — read it for the system overview, information architecture, iCloud model, implementation stance, locked decisions, and changelog.

This directory holds the detailed specifications that were too large to keep readable inside a single overview file. Each file below is authoritative for its domain; `technical-design.md` links into these files by section.

---

## Files

| File | Contents |
|---|---|
| [`core-domain.md`](core-domain.md) | Internal data model (canonical entities), application module layout, service responsibilities |
| [`containers-and-budgets.md`](containers-and-budgets.md) | Workspace folder structure, file classification rules, all CSV and Markdown file specifications (§8.1 – §8.28) |
| [`rulesets-and-taxes.md`](rulesets-and-taxes.md) | Validation rules (file-level, cross-file, domain), UI requirements per module section |
| [`data-pipelines.md`](data-pipelines.md) | Read/write/repair flows, ingestion pipeline diagrams, scripts and developer tooling |

---

## Quick navigation

| Question | Go to |
|---|---|
| Column names, required vs optional for a specific CSV file | `containers-and-budgets.md §3` |
| What `AccountEngine` or `BudgetEngine` is responsible for | `core-domain.md §3` |
| Swift module layout — where does a file live? | `core-domain.md §2` |
| Which validation errors are auto-repairable | `rulesets-and-taxes.md §1` |
| What each module screen must show (UI spec) | `rulesets-and-taxes.md §2` |
| How a write, edit, or delete flows through the system | `data-pipelines.md §1` |
| How external CSV is ingested and normalized | `data-pipelines.md §3` |
| Which developer scripts exist and what they do | `data-pipelines.md §2` |

---

## Schema naming — Round 6 renames (applied globally)

All files in this directory use the Round 6 object names:

| Old name | New name |
|---|---|
| `entities.csv` | `account-groups.csv` |
| `entity_id` | `account_group_id` |
| `entity_type` | `group_type` |
| `holdings.csv` | `assets.csv` |
| `holding_id` | `asset_id` |
| `market_value` | `current_value` |
| `deductions.csv` | `tax-adjustments.csv` |
| `deduction_id` | `tax_adjustment_id` |
| `deduction_type` | `adjustment_type` |

See `docs/technical-design.md §21` for the full locked-decision record.
