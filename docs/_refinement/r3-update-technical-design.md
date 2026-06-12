# Technical Design Update Plan — Round 3

Source: `docs/_refinement/r3-review.md` (user direction — sidebar refinement + lock Phase 1 decisions)
Target: `docs/technical-design.md`
Status: Applied 2026-06-10 *(reconstructed retroactively 2026-06-12)*

---

> **Reconstructed retroactively.** Round 3 was applied directly to the technical design on
> 2026-06-10. This plan is written after the fact to match the existing "Round 3 — 2026-06-10"
> technical-design changelog entry. Only the technical design changed in this round.

## Summary

A navigation-structure refinement plus the locking of all remaining Phase 1 architectural
decisions. No PRD or roadmap changes.

## Section-by-Section Changes

### §4 Information architecture

- Clarified the sidebar as static with expandable groups only where specified.
- Overview: removed the "Dashboard" sub-item (Overview is now a leaf).
- Accounts: renamed "All accounts" → "Overview" and "Themes & Entities" → "Themes / entities";
  removed "Specific account links" and "Specific category links".
- Savings & Investments: replaced the nested Goals/Portfolio tree with flat items
  (Overview, Goals, Assets, Portfolio).
- Taxes: simplified to three items (Current tax year, Prep checklist, Tax archive); removed
  Estimated payments, Gains & income, and Deductions as sidebar items.
- Added the data-driven links note (Themes / entities populated from `Accounts/entities.csv`);
  removed abstract sidebar list items (Workspace root, Nested saved views, Nested report links);
  removed "Business" from the module-sections filter note (it is a theme type).

### §5 Workspace and iCloud model

- Updated workspace resolution to the confirmed iCloud container identifier `OpenFinance`;
  updated the code example.

### §6 Workspace folder structure

- Removed `Investments/accounts.csv` from the tree; updated the folder design rule to reflect the
  unified master registry.

### §8 File specifications

- §8.2: Clarified the `amount` column note with the locked sign convention; added the import
  normalization rule.
- §8.7: Removed the separate `Investments/accounts.csv` spec; replaced with a note redirecting to
  the unified `Accounts/accounts.csv`.
- §8.21: Added optional investment-specific columns (`tax_treatment`, `performance_tracking`) to
  the master registry; updated the bootstrap note to list six seed accounts.

### §9 Metadata model

- Updated the `schema_version` attribute description; added the "Schema version migration policy"
  subsection.

### §10 Internal data model

- Updated the `Account` entity note to remove `InvestmentAccount` as a separate type; investment
  fields are optional properties on `Account`.

### §14 Scripts and developer tooling

- Updated `bootstrap-workspace` to list six seed accounts.

### §16 UI requirements

- Restructured Savings & Investments requirements under nav-item headings (Goals, Assets,
  Portfolio) — sleeve content assigned to Portfolio.
- Restructured Taxes requirements under nav-item headings (Current tax year, Prep checklist, Tax
  archive) — Estimated payments, Gains & income, and Deductions placed within Current tax year.

### §21 Decisions to lock before build

- Locked all six previously-open Phase 1 decisions; added the iCloud container identifier and the
  workspace bootstrap seed accounts as additional locked decisions; added a Phase 2 locked section
  with the amount sign convention and the `schema_version` migration policy.

## Changelog entry (already present in technical-design.md)

The corresponding entry is the existing "### Round 3 — 2026-06-10" block in
`technical-design.md` §24.
