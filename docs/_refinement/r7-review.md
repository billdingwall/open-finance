---
round: 7
date: 2026-06-24
type: synthesis / mvp-prep
summary: Initial round-7 draft synthesized from the architectural audit and the R6 gap analysis — focus is MVP readiness before the Phase 1 build
status: R7 extended 2026-06-24 — Section E (development environment) added; E1 applied, E2–E4 DECIDE items open
inputs:
  - docs/_notes/architectural-audit.md
  - docs/_notes/r6-gap-analysis.md
docs reviewed for prioritization:
  - docs/product-requirements.md
  - docs/technical-design.md
  - docs/product-roadmap.md
  - docs/project-management.md
---

# Round 7 Review — MVP Prep

## Purpose

Round 6 closed out the object-model restructuring (account-groups, assets,
tax-adjustments; Liability and Portfolio as first-class objects; multi-entry
transactions; unified trade ledger). Two follow-up audits have since landed:

1. **`architectural-audit.md`** — a system-level read of the design and prototype,
   calling out functional gaps, undefined semantics, and execution risks.
2. **`r6-gap-analysis.md`** — a delivery audit of Round 6, identifying which
   recommendations were applied to the docs and which were missed.

This round is **not** a prototype review. It is a consolidation pass whose goal is
to get the project genuinely *build-ready* for Phase 1: close the doc-sync debt
left by Round 6, force the small number of decisions that block downstream phases,
and lock the V1 boundary on a few areas where the docs still waffle.

The body below synthesizes both inputs into themes with a proposed priority. The
final section translates these into **prioritized requirements updates** for the
principal to review before we open per-doc update plans (`r7-update-{doc}.md`).

---

## Priority key

| Tag | Meaning |
|---|---|
| **P0** | Blocks the Phase 1 build or leaves a core V1 capability undefined. Resolve this round. |
| **P1** | Doc-sync debt or a decision that blocks a specific later phase. Resolve this round or schedule explicitly. |
| **P2** | Real improvement or forward-looking item. Track so it isn't lost; can defer. |

---

## A. Doc-sync debt carried over from Round 6 (from `r6-gap-analysis.md`)

> **Status: All A items applied 2026-06-24.** See applied-changes summary below each item.

The R6 schema work was applied cleanly to the PRD, technical design, and roadmap,
but four follow-through items were missed. These are the cheapest, highest-value
fixes available this round because they are pure execution — no new decisions.

- **A1 — `project-management.md` is out of sync with R6 (P0).** ✅ Applied 2026-06-24
  The pre-build tracker still references pre-R6 names and is missing migration
  tasks for the three renames, the two new files (`liabilities.csv`,
  `portfolios.csv`), and the `migrate-r6.swift` script. It still contains stale
  `[FIX]` items that R6 already resolved (e.g. C1 `InvestmentAccount`,
  C6 `BusinessEntity`→`Entity`, M3 entity reconciliation, M6 `Personal/Business`
  transactions). A build planned off a stale tracker will re-litigate settled
  decisions. *Gap-analysis severity: High.*
  > **Applied:** `docs/project-management.md` updated — [FIX-C1], [FIX-C5], [FIX-S8] retired with strikethrough (resolved in R4/R7); five R6 migration FIX items added to Phase 2 Development (R6-M1 through R6-M5); prototype update task added as [FIX-R7-P1]; item counts table updated.

- **A2 — Prototype not updated to the R6 schema (P1).** ✅ Partially applied 2026-06-24
  `prototype/data.js` / `store.js` still use the old mock collections
  (`entities`, `holdings`, `deductions`) and lack liabilities, portfolios, and the
  new transaction fields (`group_id`, `group_role`, `liability_id`, `trade`/`credit`
  types). If the prototype is our primary review vehicle, the next review round
  cannot validate R6 against it until this is done. No roadmap task captures the
  work. *Gap-analysis severity: High.*
  > **Applied (partial):** `prototype/data.js` stale file paths corrected — `Investments/transactions.csv` references updated to `Accounts/transactions/YYYY-MM.csv` (realizedGains, incomeSummary); `Personal/transactions/*.csv` and `Personal/categories.csv` references updated in issues table (iss-001 through iss-003, iss-008). Most R6 entity renames (`accountGroups`, `assets`, `taxAdjustments`, `liabilities`, `portfolios`, `multiEntryExamples`) were already applied in a prior session. Write/edit flow prototype updates remain outstanding and are now tracked as `[FIX-R7-P1]` in `docs/project-management.md` and a Phase 6 Design task in the roadmap.

- **A3 — `technical-design.md` is a monolith; file-org proposal not executed (P2).** ✅ Applied 2026-06-24
  The proposed `docs/architecture/` split (`index.md`, `core-domain.md`,
  `containers-and-budgets.md`, `rulesets-and-taxes.md`, `data-pipelines.md`) was
  not created. The single file is becoming a bottleneck for review and diffing.
  Worth doing, but it is a refactor of *how* we document, not *what* we build —
  defer behind A1/A2. *Gap-analysis severity: Medium.*
  > **Applied:** `docs/architecture/` created with five files (`index.md`, `core-domain.md`, `containers-and-budgets.md`, `rulesets-and-taxes.md`, `data-pipelines.md`). `docs/technical-design.md` reduced to a ~500-line lean overview; §6/7/8/10/11/12/13/14/15/16 replaced with 2-line stubs linking to architecture files. `CLAUDE.md`, `README.md` updated to reference the new architecture directory. FIX-C5 (manifest path) and FIX-S8 (advanced workspace V2 marker) applied during this refactor.

- **A4 — No data-flow / ingestion pipeline diagrams (P2).** ✅ Applied 2026-06-24
  The import → normalize → `Transaction` → balance-update pipeline is the most
  complex path in the system and has no visual documentation. Pairs naturally with
  A3 (lives in `data-pipelines.md`). *Gap-analysis severity: Medium.*
  > **Applied:** Four ASCII pipeline diagrams added to `docs/architecture/data-pipelines.md §3`: CSV import/normalization pipeline (§3.1), balance derivation pipeline (§3.2), multi-entry transaction group write pipeline (§3.3), and file-watch re-index pipeline (§3.4).

- **A5 — Live market data not tracked anywhere (P2).** ✅ Applied 2026-06-24
  A forward-looking item with no home in the roadmap, PRD non-goals, or project
  tracker. It is already V1-out-of-scope ("Real-time market data"), so the action
  is simply to record it as a tracked V2 candidate so it isn't rediscovered cold.
  *Gap-analysis severity: Low.*
  > **Applied:** "Live price ingestion strategy (endpoint choice, polling interval, error handling)" added to `docs/product-roadmap.md` Out of Scope table as an explicit V2 tracked item alongside "Real-time market data".

---

## B. Functional & semantic gaps (from `architectural-audit.md`)

> **Status: All B items applied 2026-06-24.**

- **B1 — Delete-on-reference behavior is still undecided (P0).** ✅ Applied 2026-06-24
  Both audits flag this, and the roadmap lists it as an Open Decision for Phase 6.
  But PRD §12 already commits us to delete for *every* user-addable object with a
  "reference check" — without defining what the check *does* (block / cascade-warn
  / reassign). Deleting an account or category with hundreds of linked transactions
  has no defined behavior. This is the single most load-bearing undefined V1
  semantic. *Audit severity: High.*
  > **Direction:** Reassign. Delete flow surfaces referencing rows + per-collection picker. Delete + reassignments written atomically.
  > **Applied:** `docs/product-requirements.md §12`, `docs/architecture/rulesets-and-taxes.md §1`, `docs/technical-design.md §21`, `docs/product-roadmap.md` Open Decisions — all updated to reflect reassign as the locked behavior.

- **B2 — Write/edit flows missing from the prototype (P1).** ✅ Tracked 2026-06-24
  PRD §12 makes universal add/edit/delete a V1 requirement, but the prototype
  inspector is read-only and the documented write-preview / safe-write behavior is
  not demonstrated. This is a prototype-fidelity gap, not a spec gap. *Audit severity: High.*
  > **Direction:** Add to prototype.
  > **Applied:** Tracked as `[FIX – R7-P1]` in `docs/project-management.md` and as a Phase 6 Design task in `docs/product-roadmap.md`. Prototype update is a future execution task.

- **B3 — Business: domain vs. theme ambiguity persists (P1).** ✅ Applied 2026-06-24
  The audit and `project-management.md` [FIX-C3]/[S2] both flag that Business is
  modeled inconsistently: Tech Design §11 lists `Business/BusinessEngine.swift`,
  but §12 assigns all business P&L to `AccountEngine`. *Audit severity: (structural).*
  > **Direction:** Business is a group type (`group_type = business`) under Accounts. No standalone BusinessEngine. AccountEngine owns all business P&L.
  > **Applied:** `docs/architecture/core-domain.md §2–3` updated (note updated to "resolved"; BusinessEngine removed from module layout); `docs/technical-design.md §21` locked decision added; `docs/project-management.md` [FIX-C3] and [FIX-S2] retired.

- **B4 — Markdown viewer scope still waffles (P1).** ✅ Applied 2026-06-24
  PRD §4 says "provide a readable native viewer in v1" while the out-of-scope list
  and roadmap defer the Notes viewer/editor to V2. `project-management.md` [FIX-S1]
  already names this. *Audit severity: (scope).*
  > **Direction:** Markdown viewer/editor is V2 and consistent across docs. In v1, only front matter is parsed.
  > **Applied:** `docs/product-requirements.md §4` updated; `docs/technical-design.md §21` locked decision added; `docs/project-management.md` [FIX-S1] retired.

---

## C. Architecture & execution risks (from `architectural-audit.md`)

> **Status: All C items applied or confirmed 2026-06-24.**

- **C1 — iCloud concurrency / conflict resolution underspecified (P1).** ✅ Applied 2026-06-24
  The design names a "Conflict detected" UI state but does not specify how concurrent offline edits are resolved. *Audit severity: High.*
  > **Direction:** Sync-first write pattern. Sync from iCloud before allowing UI write actions. Disable write actions while sync is in progress.
  > **Proposed implementation (applied to docs):**
  > - `ICloudContainerService` exposes per-file sync state; write actions gate on `available` state
  > - On launch: show "Syncing workspace…" and disable write actions until all files are `available`
  > - On write attempt: `WritePlanBuilder` checks sync state; blocks with inline "File syncing — edits will be available shortly" if not available
  > - On iCloud push: `FileWatcherService` marks affected file as downloading; write actions disabled until re-index completes
  > - `NSFileCoordinator` serializes all file reads/writes at the OS level
  > **Applied:** `docs/architecture/core-domain.md §3` (ICloudContainerService); `docs/product-requirements.md` NFR Reliability; `docs/technical-design.md §21` locked decision.

- **C2 — Re-index / file-watch performance at scale (P2).** ✅ Applied 2026-06-24
  Multi-year transaction history across dozens of CSVs could make full re-index a main-thread hazard on low-power Macs. *Audit severity: Medium.*
  > **Direction:** Target higher-performance Macs (M1+). Longer sync times on older Intel hardware are acceptable.
  > **Applied:** `docs/product-requirements.md` NFR Performance; `docs/technical-design.md §21` locked decision.

- **C3 — Bootstrap / demo-data onboarding (P2).** ✅ Confirmed — looks good.
  Pre-filled demo dataset de-risks first-use and doubles as the dev fixture (`fixture-generate.swift` already exists). *Audit severity: (improvement).*
  > **Direction:** Looks good. No change needed. `fixture-generate.swift` already tracked in roadmap Phase 7.

- **C4 — `AccountEngine` monolith risk (P2).** ✅ Confirmed — already applied.
  The mitigation — keep AccountEngine to read-only projection interfaces — should be a stated design constraint. *Audit severity: Medium.*
  > **Direction:** Looks good. Already documented in `docs/architecture/core-domain.md §3` (AccountEngine) as an explicit design constraint.

- **C5 — Tax scope creep guardrail (P2).** ✅ Applied 2026-06-24
  Audit rates "tax logic expands into real calculation" as High severity / Low likelihood. The existing non-goal ("Tax return filing") needs to be more specific. *Audit severity: High / Low likelihood.*
  > **Direction:** Add explicit guardrail focused on estimating tax payments based on income and income types. Primary goal is to understand tax payment obligations and organize documents.
  > **Applied:** `docs/product-requirements.md §8` tax scope guardrail statement added; non-goals updated to "Tax return filing or tax computation engine"; `docs/technical-design.md §21` locked decision added.

---

## D. Synthesis — what this round should actually do

Cutting across A–C, Round 7 has three workstreams:

1. **Pay down R6 doc debt** (A1 P0, A2 P1, then A3/A4/A5 P2) — mechanical, do first.
2. **Force the two V1-blocking decisions** — delete-on-reference (B1 P0) and the
   Business domain/theme model (B3 P1) — and lock two scope boundaries
   (Markdown B4, tax guardrail C5).
3. **Make the write/concurrency story real** before Phase 6 — prototype write flows
   (B2), conflict resolution (C1), with performance/bootstrap/engine-shape
   constraints (C2–C4) recorded as explicit criteria rather than assumptions.

---

## E. Development environment — toolchain, platform requirements, and CI/CD

> **Status: E1 direction confirmed and applied 2026-06-24 (`CLAUDE.md` updated). E2–E4 open — DECIDE items added to `project-management.md` Phase 1.**

The primary development toolchain has been specified by the principal. Three platform decisions remain open and block Phase 1 Xcode project creation. A CI/CD strategy is absent from all current docs.

- **E1 — Development toolchain: Claude Code + Antigravity 2.0 / Antigravity IDE + Figma MCP (P0).** ✅ Applied 2026-06-24
  The confirmed dev environment is:
  - **Claude Code** (primary AI dev assistant) — context file is `CLAUDE.md`. Session-start hook and build/test commands will be added once the Xcode project is created in Phase 1. MCP server configuration for Figma lives in `.claude/settings.json`.
  - **Google Antigravity 2.0 / Antigravity IDE** (primary IDE) — code editing environment. Xcode remains required as the macOS build toolchain; Antigravity does not replace Xcode for building and running SwiftUI apps. IDE-specific project settings must not conflict with Xcode project settings.
  - **Figma MCP tools** — CLI and MCP server tooling that gives the AI assistant direct read access to design specs, design tokens, and component annotations from the Figma workspace. Bridges `docs/_design/` assets to the implementation workflow. MCP server configuration must be documented in `CLAUDE.md` and `.claude/settings.json` once finalized in Phase 1.
  - VS Code and Kiro are later-phase candidates; no immediate doc changes required.
  > **Direction:** Toolchain confirmed. CLAUDE.md updated with development toolchain section. Figma MCP server config is a Phase 1 task.
  > **Applied:** `CLAUDE.md` — new "Development toolchain" section added covering all four tools, pending platform DECIDE items, and Figma MCP configuration note.

- **E2 — macOS deployment target, Xcode version, and Swift version are unspecified (P0).**
  All three are absent from every doc. They block Phase 1 Xcode project creation and implicitly gate every feature decision in Phases 1–5 — which SwiftUI modifiers, `@Observable` (Observation framework), and Swift Charts APIs are available depends entirely on the macOS target. Key constraint: `@Observable` requires macOS 14 (Sonoma) minimum. Given the M1+ hardware target locked in C2, macOS 14 is the likely minimum floor.
  Xcode version must be pinned for build reproducibility across Claude Code, Antigravity IDE, and any CI environment. Swift version follows from Xcode version and should be stated explicitly.
  > **Direction needed.** Recommend macOS 14 (Sonoma) as the minimum deployment target — broadest M1-compatible target that includes `@Observable` and Swift Charts. Xcode and Swift version TBD.
  > **Tracking:** Three `[DECIDE]` items added to `project-management.md` Phase 1 Development.

- **E3 — No CI/CD strategy documented (P1).**
  Phase 1 Development already includes "Set up SwiftLint and code style configuration" but with no CI context — no platform, no trigger, no scope. For a macOS SwiftUI app, full build CI requires a Mac runner (unavailable on standard GitHub Actions free tier; expensive on paid). Practical options: (a) SwiftLint + doc/script checks only, running on a Linux runner; (b) full build check on a self-hosted Mac runner; (c) defer build CI entirely and rely on developer machines. The absence of a CI decision means the Phase 1 SwiftLint task has no deployment context.
  Additionally, iCloud entitlements and signing certificates present a CI-specific problem: a CI runner has no Apple Developer account. This intersects with the existing `[DECIDE]` for the iCloud entitlement strategy.
  > **Direction needed.** Add `[DECIDE]` item to `project-management.md` Phase 1 Development.

- **E4 — Figma → code handoff policy not defined (P1).**
  Design assets are in `docs/_design/`, and design tasks span all roadmap phases. With Figma MCP tooling confirmed in E1, the AI assistant can read directly from Figma rather than requiring manual exports — but the workflow must establish what the MCP server exposes, naming conventions for tokens and components, and which assets are committed to `docs/_design/` versus read live from Figma at authoring time. Without this policy, Phase 1 design output (global app shell, onboarding) has no defined handoff path to Phase 5 implementation.
  > **Direction needed.** Add `[DECIDE]` item to `project-management.md` Phase 1 Design.

---

## Proposed requirements updates — prioritized

This section translates the findings above into concrete edits, scoped primarily to
`docs/product-requirements.md` with the cascading doc each one touches. Ordered by
priority for principal review. (No edits applied yet — this is the proposal set.)

### P0 — resolve this round (blocks build / undefined core V1 behavior)

| # | Proposed requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 1 | **Define delete-on-reference behavior** and write it into PRD §12. Pick a default (recommend: *block + show referencing rows*, with explicit reassign/cascade only where it reads naturally). Resolve the matching roadmap Open Decision and `project-management.md` Phase 6 [DECIDE] to the same answer. | PRD §12 | technical-design (RepairService / write model), roadmap Open Decisions, project-management | B1 |
| 2 | **Re-sync `project-management.md` to the R6 object model.** Retire resolved [FIX] items (C1, C6, M3, M6, and any naming items R6 closed); add migration tasks for the three renames, `liabilities.csv` + `portfolios.csv`, and `migrate-r6.swift`. Not a PRD edit, but it gates an accurate build plan. | project-management | — | A1 |
| 13 | **Pin macOS deployment target, Xcode version, and Swift version** before Phase 1 Xcode project creation. Document in `CLAUDE.md`, `docs/technical-design.md §2`, and `README.md`. These three values gate every SwiftUI API and framework feature decision in Phases 1–5. Add three `[DECIDE]` items to `project-management.md` Phase 1 Development. | CLAUDE.md, technical-design §2 | README.md, roadmap Phase 1 Xcode setup task, project-management | E2 |

### P1 — resolve this round or schedule explicitly (blocks a later phase)

| # | Proposed requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 3 | **Settle Business as group-under-Accounts vs. standalone module** and state it in PRD §5. Then align Tech Design §11/§12 (remove or formalize `BusinessEngine`) and the roadmap. | PRD §5 | technical-design §11/§12, roadmap, project-management [FIX-C3/S2] | B3 |
| 4 | **Bound Markdown scope in PRD §4**: inline rendering in the right detail pane is V1; standalone Notes module is V2; name the supported subset (headers, tables, links). | PRD §4 | roadmap (Notes V2), project-management [FIX-S1] | B4 |
| 5 | **Add a write-safety / conflict-resolution requirement** to PRD §1 and the Reliability NFR: atomic temp-then-rename, timestamped backup, and a user-driven conflict-winner flow for concurrent edits. | PRD §1 + NFR | technical-design (FileCoordinatorService, sync states), roadmap Phase 1/6 | C1 |
| 6 | **Add prototype tasks** to bring it to the R6 schema (A2) and to demonstrate write/edit/delete + write-preview (B2). Roadmap/tracker tasks, not PRD requirements. | roadmap / project-management | prototype/ | A2, B2 |
| 14 | **Document development toolchain in `CLAUDE.md`** — Claude Code, Antigravity 2.0 / Antigravity IDE, Figma MCP tools, secondary IDE candidates. Add Figma MCP server configuration as a Phase 1 task. Not a PRD requirement, but gates correct AI assistant behavior from Phase 1 onward. | CLAUDE.md | project-management Phase 1 | E1 |
| 15 | **Define CI/CD pipeline** — platform (GitHub Actions), what runs on PR (SwiftLint minimum; build check scope TBD), and how signing/entitlements are handled in a CI environment without a Mac developer account. Add `[DECIDE]` to `project-management.md` Phase 1 Development. | project-management | roadmap Phase 1 Xcode setup task | E3 |
| 16 | **Define Figma → code handoff policy** — what the Figma MCP server exposes, naming conventions for design tokens and components, and which assets are committed to `docs/_design/` vs read live. Add `[DECIDE]` to `project-management.md` Phase 1 Design. | project-management | docs/_design/, CLAUDE.md | E4 |

### P2 — track now, may defer

| # | Proposed requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 7 | **Add measurable performance acceptance criteria** (cold launch to first projection; full re-index of a realistic dataset; responsiveness during background re-index) to the Performance NFR. | PRD NFR | roadmap Phase 7 [DECIDE] | C2 |
| 8 | **State the `AccountEngine` read-only-projection constraint** as an explicit design principle. | technical-design §12 | CLAUDE.md architecture note | C4 |
| 9 | **Record bootstrap demo-data** as a first-run/onboarding requirement candidate (doubles as the dev fixture). | PRD §1 / roadmap Phase 1 | technical-design bootstrap | C3 |
| 10 | **Split `technical-design.md`** into `docs/architecture/` and add the ingestion **pipeline diagrams**. | technical-design | new docs/architecture/ | A3, A4 |
| 11 | **Track live market data** as an explicit V2 candidate in the roadmap out-of-scope list (already a V1 non-goal). | roadmap | PRD non-goals (reference) | A5 |
| 12 | **Keep the tax-scope guardrail explicit** — reaffirm "no tax-filing/calculation engine in V1" where write/tax requirements are described. | PRD §8 / non-goals | constitution (reference) | C5 |

### Applied 2026-06-24

All 12 original proposed updates applied inline to the affected documents. Section E items 13–16 extended the round; E1 applied same day, E2–E4 tracked as open DECIDE items.

| # | Status | Docs updated |
|---|---|---|
| 1 | ✅ B1 — delete: reassign | PRD §12, rulesets-and-taxes.md §1, technical-design §21, roadmap Open Decisions |
| 2 | ✅ A1 — project-management re-sync | project-management.md (FIX items retired, R6 tasks added) |
| 3 | ✅ B3 — Business = group type | core-domain.md §2–3, technical-design §21, project-management (FIX-C3/S2 retired) |
| 4 | ✅ B4 — Markdown: V2 | PRD §4, technical-design §21, project-management (FIX-S1 retired) |
| 5 | ✅ C1 — sync-first write gate | PRD NFR Reliability, core-domain.md §3 (ICloudContainerService), technical-design §21 |
| 6 | ✅ A2/B2 — prototype tasks | project-management [FIX-R7-P1], roadmap Phase 6 Design task |
| 7 | ✅ C2 — performance: M1+ | PRD NFR Performance, technical-design §21 |
| 8 | ✅ C4 — AccountEngine constraint | Already applied (core-domain.md §3) — confirmed |
| 9 | ✅ C3 — bootstrap demo-data | Already tracked (roadmap Phase 7 fixture-generate.swift) — confirmed |
| 10 | ✅ A3 — architecture split | docs/architecture/ created, technical-design.md lean overview |
| 11 | ✅ A4/A5 — pipeline diagrams + V2 tracking | data-pipelines.md §3, roadmap Out of Scope |
| 12 | ✅ C5 — tax scope guardrail | PRD §8 + non-goals, technical-design §21 |
| 13 | ⏳ E2 — macOS/Xcode/Swift pinning | DECIDE items added to project-management.md Phase 1 Development — awaiting direction |
| 14 | ✅ E1 — development toolchain documented | CLAUDE.md — new "Development toolchain" section added |
| 15 | ⏳ E3 — CI/CD pipeline | DECIDE item added to project-management.md Phase 1 Development — awaiting direction |
| 16 | ⏳ E4 — Figma → code handoff policy | DECIDE item added to project-management.md Phase 1 Design — awaiting direction |
