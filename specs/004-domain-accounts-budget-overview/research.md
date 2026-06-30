# Phase 0 Research: Domain Layer I — Accounts, Budget & Overview

All four material ambiguities were resolved in the spec's `/speckit-clarify` Session 2026-06-30, so
there are no open `NEEDS CLARIFICATION`s. This document records the engineering decisions that follow
from those answers plus the locked architecture, so the design artifacts and tasks are unambiguous.

## R1 — Record mapping seam (`ParsedRecord` → typed domain entities)

- **Decision**: Add a `Domain/Mapping/RecordMappers.swift` layer that converts the Phase-2
  `ParsedRecord` (a `[String: FieldValue]` with a `TypedValue?`) into the existing Phase-1 typed
  structs (`Account`, `AccountGroup`, `Liability`, `AccountRule`, `AccountEstimate`,
  `UnifiedTransaction`, `Category`, `Budget`, `BudgetAllocation`, `SavingsGoal`). Each mapper is a
  pure `static func map(_ record: ParsedRecord) -> Entity?` returning `nil` (and leaving the
  underlying validation issue to the existing stream) when a required field is missing/invalid.
- **Rationale**: Phase 2 deliberately stops at generic records; the engines need typed input. One
  shared seam avoids each engine re-reading raw fields, and preserves `sourceFile`/`sourceRow`
  provenance for Phase 5 traceability. Mapping reads typed values straight off `FieldValue.typed`, so
  no re-parsing or re-normalization happens here.
- **Alternatives considered**: (a) `Codable` decoding from records — rejected: `FieldValue` already
  carries typed values and validity, so a hand-written mapper is simpler and keeps the partial-record
  semantics. (b) Mapping inside each engine — rejected: duplicates field-name knowledge four times.

## R2 — As-of date injection (deterministic "current period")

- **Decision**: Every engine entry point takes an explicit `asOf: Date` parameter (and the engines
  derive the current month via a fixed `Calendar(identifier: .gregorian)` in the workspace timezone).
  CLIs and the future app default `asOf` to `Date()`; tests inject a fixed date. No engine reads the
  system clock internally.
- **Rationale**: Resolves the clarify answer ("as-of date's month, injectable"). Pure functions of
  (context, asOf, settings) are deterministic and trivially testable — essential for the sparse,
  gap-month, and empty-current-month fixtures.
- **Alternatives considered**: Reading `Date()` inside engines (non-deterministic tests); a `Clock`
  abstraction (heavier than needed for a value-in parameter).

## R3 — YTD window anchoring

- **Decision**: YTD = Jan 1 of `WorkspaceSettings.taxYear` (from `Taxes/settings.csv` via the Phase-2
  `SettingsStore`) through the last day of the as-of month. A transaction is "in YTD" when its `date`
  falls in `[Jan 1 taxYear, end of asOf month]`.
- **Rationale**: Clarify answer ("workspace tax year"). Ties every YTD figure to the same year the
  Phase-4 Tax module will reckon against, and stays deterministic under the injected as-of date.
- **Alternatives considered**: System calendar year (clock-coupled); rolling 12 months (diverges from
  tax reckoning).

## R4 — `taxes_paid` term in YTD net income

- **Decision**: `taxes_paid` for an account/group = the sum of ledger legs with
  `group_role = withholding` (negative/debit amounts) plus ledger rows whose category is tax-relevant
  in a "tax payment" sense, **within that group's accounts and the YTD window**.
  `Taxes/estimated-payments.csv` is **not** consumed by `AccountEngine` (it has no account/group link
  and feeds the Phase-4 Tax module).
- **Rationale**: Clarify answer ("ledger withholding legs"). Keeps `AccountEngine` ledger-pure and
  per-group-attributable, honoring FR-009 (no Tax-domain logic absorbed) since it reads only the
  ledger, not tax files.
- **Alternatives considered**: estimated-payments.csv (unattributable per group without a new
  column); both sources (adds an attribution scheme — deferred to Phase 4).

## R5 — Transfer exclusion & multi-entry group resolution

- **Decision**: Rows with `type = transfer` are excluded from both gross and expenses everywhere.
  Multi-entry groups (shared `group_id`) are resolved before aggregation: transfer/liability groups
  must net to zero and contribute nothing to income/expense; paycheck groups expose exactly one
  `gross` and one `net` leg with `net = gross − Σ(withholding)` — income counts the `gross` leg,
  `taxes_paid` counts the `withholding` legs, and the `net` leg is not separately counted (avoids
  double counting). Trade rows (`type = trade`) are ignored by `AccountEngine` (Phase-4 Portfolio).
- **Rationale**: Matches `containers-and-budgets.md §3.2` multi-entry semantics and the Phase-2
  group-balance validation rules already in `DomainRules`. Keeps internal moves from reading as
  income/expense (FR-005/FR-007).
- **Alternatives considered**: Counting net legs as income (double counts); ignoring groups (transfers
  leak into expense totals).

## R6 — Balance & liability principal derivation

- **Decision**: `Account.current_balance` = signed sum of all the account's ledger amounts (debit
  negative, credit positive) up to the as-of date. `Liability.principal_balance` = signed sum of the
  ledger entries carrying its `liability_id` (draw-downs increase, payments decrease). Both are
  computed, never read from the CSV's cached column.
- **Rationale**: Constitution Principle II (derived, regenerable) and FR-004. The cached CSV columns
  are display conveniences written in Phase 6, not a source of truth.
- **Alternatives considered**: Trusting the cached column (violates regenerability; stale on import).

## R7 — 3-month trailing average with partial confidence

- **Decision**: Represent the result as a `TrailingAverage { value: Decimal, monthsAvailable: Int,
  isPartial: Bool }`. Average the actuals of the up-to-3 months immediately preceding the as-of
  month that have data; `isPartial = monthsAvailable < 3`. Never return zero/blank for a category
  with ≥1 month of data; a category with zero months returns `monthsAvailable = 0` (the UI renders a
  dash — but the value field stays a real optional, not a misleading 0).
- **Rationale**: Clarify-confirmed roadmap rule (partial average + data-sufficiency label). The
  months-available count drives the Phase-5 "avg of N mo" label.
- **Alternatives considered**: Returning a bare `Decimal` (loses the sufficiency signal); zero-filling
  (the explicitly rejected misleading-zero behavior).

## R8 — Overview stub contract & card sourcing

- **Decision**: `OverviewSummaryCard` carries a `state ∈ {available, dataNotAvailable}` (already on
  the Phase-1 stub). In Phase 3: Budget card ← `BudgetEngine`; Savings card ← `AccountEngine` over
  `account_group = savings` (balance = Σ derived `current_balance`; contributions = current-month net
  inflow); Business card ← `AccountEngine` business-group P&L; Investments & Taxes cards are
  constructed in the `dataNotAvailable` state (no PortfolioEngine/TaxEngine this phase).
- **Rationale**: Matches the locked stub contract in `core-domain.md §3` and the clarify answer for
  the Savings card; lets Phase 4 slot real engines in without changing the card shape.
- **Alternatives considered**: nil/zero cards (the explicitly rejected behavior); sourcing Savings
  from BudgetEngine or goal tags (rejected in clarify).

## R9 — Month-over-month panel

- **Decision**: `MonthlySnapshot` per populated month; build the trailing 6 months ending at the
  as-of month, **including only months that have ≥1 transaction** (gap months are omitted, not
  zero-filled). Net income per snapshot uses the same transfer-excluded definition as YTD.
- **Rationale**: Clarify answer (trailing 6, skip gaps). Keeps a new/sparse workspace's sparkline
  honest.
- **Alternatives considered**: Zero-filling gaps (misleading); 12-month window (noisier early on).

## R10 — Developer CLI shape

- **Decision**: Three new `executableTarget`s — `accounts-overview`, `budget-overview`,
  `overview-dashboard` — each taking `--workspace <path>` (and an optional `--as-of YYYY-MM-DD`,
  defaulting to today), parsing via `WorkspaceParser`, running its engine, and printing a readable
  summary to stdout. They mirror `index-check` / `validate-workspace` exactly (no JSON required in
  v1; `--as-of` exists purely for reproducible runs/tests).
- **Rationale**: FR-024 + the established Phase 1/2 CLI convention; gives each user story an
  independent, demonstrable verification path with no UI.
- **Alternatives considered**: A single multiplexed CLI (couples the three stories); library-only
  (no independent demo per the spec's "Independent Test" requirement).

## R11 — Seed data placement

- **Decision**: Expand the default category set and correct the seed `account_type` values directly
  in `Platform/WorkspaceLayout.swift` (already the single source for bootstrap seeds used by both the
  app provisioner and the `bootstrap-workspace` CLI). The canonical `account_type` taxonomy is also
  encoded as `Domain/Mapping/AccountTypeTaxonomy.swift` for engine/seed reference; `account_type`
  stays a free-string schema column (forward-compatible, FR-020).
- **Rationale**: One seed source already exists; reuse it. Keeping the taxonomy as code (not a schema
  enum) honors the "free string for forward-compat" decision while still giving a canonical list to
  seed and to reference.
- **Alternatives considered**: Promoting `account_type` to a schema enum (rejected — forward-compat);
  a separate seed file (rejected — duplicates the existing `WorkspaceLayout` seam).

## Cross-references

- `docs/architecture/core-domain.md §3` — engine responsibilities + the OverviewEngine stub contract.
- `docs/architecture/containers-and-budgets.md §3.2/§3.3/§3.4/§3.14/§3.21/§3.22/§3.25` — ledger,
  categories, budgets/allocations, account-groups, accounts registry, account-rules, liabilities.
- Phase-2 code consumed: `WorkspaceParser`, `WorkspaceContext`, `CSVParseResult`/`ParsedRecord`/
  `FieldValue`/`TypedValue`, `ValidationEngine`/`RuleCatalog`, `SettingsStore`/`WorkspaceSettings`.
</content>
