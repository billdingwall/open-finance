# MEMORY.md — active state

The live snapshot of *where we are right now*. Read first for orientation. Keep it short and
current; it does **not** restate `CLAUDE.md` (instructions), the constitution, or the docs — it
points to them.

> **Last updated**: 2026-06-30

## Current phase

- **Phase 2 — Parsing, Validation & Infrastructure**: ✅ complete, merged (`003-parsing-validation`,
  PR #16; Milestone 2 gate passed). Shipped: Parsing layer, `ValidationEngine` + 34-rule catalog,
  `RepairService`, `SettingsStore`, `MigrationService`, 23 bundled JSON schemas, and the
  `validate-workspace` / `repair-workspace` / `migrate-r6` CLIs.
- **Phase 3 — Domain Layer I (Accounts, Budget, Overview)**: ⏭️ next, not started.

## Immediate next steps

1. Kick off Phase 3 via Spec Kit (`/speckit-specify` → `004-…`).
2. Build **`AccountEngine` first** — it owns the master registry (`Accounts/accounts.csv`) every
   other domain depends on.
3. Then `BudgetEngine` and `OverviewEngine` (with stubs for not-yet-built engines).

## Recent decisions

- Established the **design system**: `DESIGN.md` (native-macOS-first, full light + dark semantic
  tokens, CSS ↔ SwiftUI) + 5 design skills + a non-negotiable design-adherence gate.
- Added two living build docs: `docs/out-of-scope-followups.md` (deferred-during-implementation
  items) and `docs/test-plans.md` (app testability).
- Harmonized the four root docs (`CLAUDE.md` = AI instructions, `MEMORY.md` = active state,
  `DESIGN.md` = design system, `README.md` = human onboarding) to remove redundancy.

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
