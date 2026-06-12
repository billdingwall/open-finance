---
round: 3
date: 2026-06-10
type: user-direction
summary: Sidebar navigation refinement and locking of all Phase 1 architectural decisions
status: applied
reconstructed: 2026-06-12
---

> **Reconstructed retroactively on 2026-06-12.** Round 3 was a user-direction revision applied
> directly to `technical-design.md` on 2026-06-10 without going through the refinement loop at
> the time. This file documents the source direction so the `_refinement/` record lines up with
> the existing "Round 3 — 2026-06-10" technical-design changelog entry. Only the technical design
> changed in this round (the PRD and roadmap were untouched), so there is a single update plan:
> `r3-update-technical-design.md`. No new doc edits result from this file.

## Direction

Two related pieces of user direction landed together:

### 1. Sidebar navigation structure refinement

* The sidebar is static — expandable groups only where explicitly specified, navigation only
  (no view-specific filters).
* Trim and rename sidebar items: remove "Dashboard" sub-item from Overview; under Accounts rename
  "All accounts" → "Overview" and "Themes & Entities" → "Themes / entities"; drop "Specific
  account/category links".
* Replace the nested Savings & Investments Goals/Portfolio tree with flat items; simplify Taxes to
  three items (Current tax year, Prep checklist, Tax archive), removing Estimated payments, Gains &
  income, and Deductions as *sidebar* items (their content stays within Current tax year).
* Establish the data-driven links pattern: `Accounts/entities.csv` populates the Themes / entities
  group.

### 2. Lock all Phase 1 architectural decisions

* All six previously-open Phase 1 decisions are locked before build starts (master accounts
  registry as a unified file, deductions file structure, tax year-close behavior, right detail pane
  default, etc.), plus the confirmed iCloud container identifier (`OpenFinance`) and the workspace
  bootstrap seed accounts. A Phase 2 locked section captures the amount sign convention and the
  `schema_version` migration policy.

### Scope

PRD and roadmap unaffected. All changes are confined to `technical-design.md` (§4 sidebar, §5
workspace resolution, §6 folder structure, §8.2/§8.7/§8.21, §9, §10, §14, §16, §21).
