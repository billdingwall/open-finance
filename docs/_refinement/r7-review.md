---
round: 7
date: 2026-06-24
type: synthesis / mvp-prep
summary: Synthesized from the architectural audit and R6 gap analysis — MVP readiness before Phase 1 build; extended with Section E (development environment) per principal direction
status: ALL DIRECTION DECISIONS APPLIED 2026-06-24 — full round complete (A–E)
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
left by Round 6, force the decisions that block downstream phases, lock the V1
boundary on a few areas where the docs still waffle, and establish the development
environment before the Phase 1 build begins.

All direction decisions were provided by the principal and applied inline. No
separate `r7-update-{doc}.md` update plans were needed.

---

## Priority key

| Tag | Meaning |
|---|---|
| **P0** | Blocks the Phase 1 build or leaves a core V1 capability undefined. Resolve this round. |
| **P1** | Doc-sync debt or a decision that blocks a specific later phase. Resolve this round or schedule explicitly. |
| **P2** | Real improvement or forward-looking item. Track so it isn't lost; can defer. |

---

## A. Doc-sync debt carried over from Round 6 (from `r6-gap-analysis.md`)

> **Status: All A items applied 2026-06-24.**

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

## E. Development environment — toolchain, platform requirements, and CI/CD

> **Status: All E items applied 2026-06-24.**

The principal specified the development toolchain. Platform versions, CI/CD
strategy, and Figma → code handoff policy were locked in the same pass and applied
to `CLAUDE.md` and `docs/architecture/core-domain.md`.

- **E1 — Development toolchain: Claude Code + Antigravity 2.0 / Antigravity IDE + figma-cli (P0).** ✅ Applied 2026-06-24
  The confirmed dev environment is:
  - **Claude Code** (primary AI dev assistant) — context file is `CLAUDE.md`. Session-start hook and build/test commands will be added once the Xcode project is created in Phase 1.
  - **Google Antigravity 2.0 / Antigravity IDE** (primary IDE) — code editing environment. Xcode remains required as the macOS build toolchain; Antigravity does not replace Xcode for building and running SwiftUI apps. IDE-specific project settings must not conflict with Xcode project settings.
  - **figma-cli** ([github.com/silships/figma-cli](https://github.com/silships/figma-cli)) — local CLI that lets Claude Code design directly in Figma Desktop via CDP (no API key, no rate limits). Not an MCP server. Yolo mode default. Design tokens (DTCG/W3C) export to `docs/_design/tokens/`; icons/SVGs to `docs/_design/icons/`. Claude Code handles installation in Phase 1.
  - VS Code and Kiro are later-phase candidates; no immediate doc changes required.
  > **Direction:** Toolchain confirmed. figma-cli is a local CLI, not an MCP server — no separate MCP config needed.
  > **Applied:** `CLAUDE.md` — new "Development toolchain" section documents all four tools, locked platform requirements (macOS 15, Xcode 16, Swift 6), and figma-cli workflow.

- **E2 — macOS deployment target, Xcode version, and Swift version (P0).** ✅ Applied 2026-06-24
  All three were absent from every doc. They block Phase 1 Xcode project creation and gate every SwiftUI, Observation, and Swift Charts API decision in Phases 1–5.
  > **Direction:** macOS 15 (Sequoia), Xcode 16, Swift 6. Update all three to the latest stable release at Phase 1 build start.
  > **Applied:** `docs/architecture/core-domain.md §2` recommended stack updated; `CLAUDE.md` platform requirements updated; `project-management.md` DECIDE items retired.

- **E3 — No CI/CD strategy documented (P1).** ✅ Applied 2026-06-24
  Phase 1 Development included "Set up SwiftLint" with no CI context. Full Mac build CI on GitHub Actions requires a Mac runner (expensive; entitlements require a developer account unavailable in CI).
  > **Direction:** GitHub Actions. Phase 1: SwiftLint on a standard Linux runner only. Full Mac build CI deferred to Phase 5. Code signing and entitlements are developer-machine only through Phase 4.
  > **Applied:** `CLAUDE.md` platform requirements updated; `project-management.md` DECIDE item retired.

- **E4 — Figma → code handoff policy (P1).** ✅ Applied 2026-06-24
  No workflow defined for how design assets in `docs/_design/` flow into implementation. figma-cli lets Claude Code read live from Figma Desktop, eliminating most manual export steps.
  > **Direction:** figma-cli reads design specs live. Design tokens exported to `docs/_design/tokens/` (DTCG/W3C). Icons/SVGs exported to `docs/_design/icons/`. Component JSX specs generated on demand, not committed.
  > **Applied:** `CLAUDE.md` figma-cli workflow documented; `project-management.md` DECIDE item retired.

---

## D. Synthesis — what this round should actually do

Cutting across A–E, Round 7 has four workstreams:

1. **Pay down R6 doc debt** (A1 P0, A2 P1, then A3/A4/A5 P2) — mechanical, do first.
2. **Force the two V1-blocking decisions** — delete-on-reference (B1 P0) and the
   Business domain/theme model (B3 P1) — and lock two scope boundaries
   (Markdown B4, tax guardrail C5).
3. **Make the write/concurrency story real** before Phase 6 — prototype write flows
   (B2), conflict resolution (C1), with performance/bootstrap/engine-shape
   constraints (C2–C4) recorded as explicit criteria rather than assumptions.
4. **Establish the development environment** before Phase 1 begins — confirm the
   toolchain (E1), lock platform versions (E2), define CI/CD strategy (E3), and
   set the Figma → code handoff policy (E4).

---

## Proposed requirements updates — applied

All 16 updates were applied inline to the affected documents. Items are ordered by
priority (P0 → P1 → P2), then by source section (A → B → C → E) within each tier.

### P0 — blocked Phase 1 build or left a core V1 capability undefined

| # | Requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 1 | **Delete-on-reference behavior locked: reassign.** Delete flow surfaces referencing rows + per-collection picker. Delete + reassignments written atomically. | PRD §12 | rulesets-and-taxes.md §1, technical-design §21, roadmap Open Decisions | B1 |
| 2 | **`project-management.md` re-synced to R6 object model.** Stale [FIX] items retired; five R6 migration tasks added. | project-management | — | A1 |
| 3 | **macOS 15, Xcode 16, Swift 6 locked.** Update to latest stable release at Phase 1 build start. Documented in recommended stack and CLAUDE.md. | core-domain.md §2, CLAUDE.md | project-management (DECIDE items retired) | E2 |

### P1 — blocked a specific later phase

| # | Requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 4 | **Business = group type under Accounts.** No standalone BusinessEngine; AccountEngine owns all business P&L. | core-domain.md §2–3, technical-design §21 | project-management (FIX-C3/S2 retired) | B3 |
| 5 | **Markdown viewer/editor: V2.** Front matter only in v1. | PRD §4, technical-design §21 | project-management (FIX-S1 retired) | B4 |
| 6 | **Sync-first write gate added to Reliability NFR.** `ICloudContainerService` exposes per-file sync state; write actions disabled while syncing; `NSFileCoordinator` serializes all I/O. | PRD NFR Reliability, core-domain.md §3 | technical-design §21 | C1 |
| 7 | **Prototype write/edit flow tasks tracked.** Add/edit/delete + write-preview added to roadmap and project-management. | project-management [FIX-R7-P1], roadmap Phase 6 | prototype/ | A2, B2 |
| 8 | **Development toolchain documented in `CLAUDE.md`.** Claude Code, Antigravity 2.0 / Antigravity IDE, figma-cli (local CDP; not an MCP server). | CLAUDE.md | core-domain.md §2 | E1 |
| 9 | **CI/CD: GitHub Actions; SwiftLint on Linux runner (Phase 1).** Full Mac build CI deferred to Phase 5. Code signing developer-machine only through Phase 4. | CLAUDE.md | project-management (DECIDE item retired) | E3 |
| 10 | **Figma → code handoff: figma-cli live reads + token export.** Design tokens → `docs/_design/tokens/` (DTCG/W3C); icons/SVGs → `docs/_design/icons/`; component specs on demand. | CLAUDE.md | docs/_design/ | E4 |

### P2 — tracked for later phases

| # | Requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 11 | **Performance target: M1+ baseline.** Longer times on older Intel hardware are acceptable. | PRD NFR Performance, technical-design §21 | — | C2 |
| 12 | **`AccountEngine` read-only constraint** stated as an explicit design principle. | core-domain.md §3 | — | C4 |
| 13 | **Bootstrap demo-data** confirmed as first-run / dev fixture path. | roadmap Phase 7 | — | C3 |
| 14 | **Architecture split** into `docs/architecture/` + ingestion pipeline diagrams added. | docs/architecture/ (5 files) | technical-design.md lean overview | A3, A4 |
| 15 | **Live market data** recorded as explicit V2 candidate in roadmap out-of-scope list. | roadmap Out of Scope | — | A5 |
| 16 | **Tax scope guardrail** — primary goals are estimating payment obligations and organizing documents; not a computation engine. | PRD §8, non-goals, technical-design §21 | — | C5 |
