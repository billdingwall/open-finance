# MEMORY.md — active state

The live snapshot of *where we are right now*. Read first for orientation. Keep it short and
current; it does **not** restate `CLAUDE.md` (instructions), the constitution, or the docs — it
points to them.

> **Last updated**: 2026-06-30

## Current phase

- **Phase 3 — Domain Layer I (Accounts, Budget, Overview)**: 🟡 **build complete on branch
  `004-domain-accounts-budget-overview`** (39/39 tasks; Milestone 3 reached) — **pending CI + merge**.
  Shipped: the `ParsedRecord`→typed-entity **record-mapping seam**, **`AccountEngine`** (aggregate /
  per-account / per-group projections, ledger-derived balances + liability principal, tax-year YTD net
  income with transfers neutral + taxes from withholding legs, personal-inflow vs **retained-equity**
  split, multi-entry + multi-employment, rule projection), **`BudgetEngine`** (plan-vs-actual,
  partial-aware 3-mo trailing average, spend-mix, goal contributions), **`LinkingEngine`** +
  **`OverviewEngine`** (5 KPI cards — Budget/Savings/Business live, Investments/Taxes "data not
  available"; gap-skipping 6-mo MoM; aggregated issues), expanded seed (16 categories / 6 groups +
  default Household budget), and the `accounts-overview` / `budget-overview` / `overview-dashboard`
  CLIs. `swift build` green; `swift test`/`swiftlint --strict` run in macOS CI (CLT-only box can't run
  them locally — engines verified behaviorally via the CLIs).
- **Phase 2 — Parsing, Validation & Infrastructure**: ✅ complete, merged (`003-parsing-validation`,
  PR #16; Milestone 2 gate passed).
- **Phase 4 — Domain Layer II (Savings, Investments, Tax)**: ⏭️ next, not started.

## Immediate next steps

1. **Push `004-domain-accounts-budget-overview`** → let `ci-macos.yml` run `swift test` + SwiftLint
   (the formal Milestone 3 gate; de-risks any test-compile issue), then open a PR and merge.
2. On merge, mark Phase 3 complete-merged across the status docs (as Phases 1/2 were).
3. Kick off **Phase 4** via Spec Kit (`/speckit-specify` → `005-…`): `SavingsGoalEngine`,
   `PortfolioEngine` + `BenchmarkEngine`, `TaxEngine` + `TaxPrepEngine` + `TaxAdjustmentEngine`;
   resolves the Phase-4 `[DECIDE]`s in `docs/project-management.md`.

## Recent decisions (Phase 3)

- **Retained equity** = taxable YTD income not part of personal monthly inflow; Phase 3 computes the
  **business** portion only (AccountEngine is ledger-only, ignores `type = trade`); investment/
  reinvested-gain retained equity → Phase 4 (`OOS-4`).
- **`taxes_paid`** = explicit tax line items (withholding legs + standalone tax-payment rows); YTD
  anchored to the workspace `tax_year`; "current period" = an injectable as-of-date month.
- **Engines are pure & read-only** — `(WorkspaceContext, asOf, settings) → projection`; verified by a
  read-only-guarantee test (SC-009).
- Additively extended the `account-rules` schema (optional `rule_type`/`amount`/`frequency`/`is_active`
  columns — non-breaking) so FR-006 rule projection has amount + frequency.
- Earlier: established the **design system** (`DESIGN.md` + 5 skills + design-adherence gate) and the
  two living build docs (`docs/out-of-scope-followups.md`, `docs/test-plans.md`).

## Known blockers / not-yet-testable

- **App is not user-testable** — `FinanceWorkspaceApp` is a diagnostic shell only; real UI is
  Phase 5. See `docs/test-plans.md`.
- **iCloud entitlement deferred** (T004) — needs the Xcode app target (Phase 5); DEBUG uses the
  local-folder provider.
- **Deferred repair classes** (optional-column injection, blank-field normalization, WriteGate
  sync-gating) — tracked as OOS-2 in `docs/out-of-scope-followups.md`, revisit with Phase 6.

## Orientation pointers

`CLAUDE.md` (how to work) · `DESIGN.md` (design) · `docs/architecture/` (specs) ·
`docs/product-roadmap.md` (plan) · persistent cross-session memory lives outside the repo at
`~/.claude/projects/.../memory/MEMORY.md`.
