# Specification Quality Checklist: Domain Layer II — Savings, Investments & Tax

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-06-30
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Engine/module names (PortfolioEngine, TaxEngine, etc.) and file paths are used as **domain
  vocabulary** carried over from the architecture docs and Phase 3 spec, not as implementation
  prescriptions — they identify the canonical entities being projected, consistent with the
  established spec style for this repo.
- Eleven clarifications are resolved inline (Clarifications §2026-06-30): savings-progress derivation,
  the savings-lifecycle/flat-list reconciliation, the benchmark return formula (simple ≤1Y / CAGR
  3Y–5Y), standard-deduction sourcing, weekend/holiday anchor handling (from `/speckit-specify`); FIFO
  tax-lot relief, the trailing-3-month goal contribution rate, the compute-both/flag-greater
  standard-vs-itemized behavior, and the dividend (`dividends.csv`) + ledger-interest income source
  (first `/speckit-clarify` pass); plus the short-term/long-term realized-gain split and the fixed v1
  prep-checklist item set + state triggers (second `/speckit-clarify` pass); plus the stored (not
  derived) Investments/Savings estimated-rate, the computed simplified tax estimate
  (projected_liability + safe-harbor, stored override), and the simplified ≈20% QBI estimate (third
  `/speckit-clarify` pass). No open `[NEEDS CLARIFICATION]` markers remain.
