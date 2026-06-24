---
round: 7
date: 2026-06-24
type: synthesis / mvp-prep
summary: Initial round-7 draft synthesized from the architectural audit and the R6 gap analysis — focus is MVP readiness before the Phase 1 build
status: DRAFT — pending principal review and direction
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

The R6 schema work was applied cleanly to the PRD, technical design, and roadmap,
but four follow-through items were missed. These are the cheapest, highest-value
fixes available this round because they are pure execution — no new decisions.

- **A1 — `project-management.md` is out of sync with R6 (P0).**
  The pre-build tracker still references pre-R6 names and is missing migration
  tasks for the three renames, the two new files (`liabilities.csv`,
  `portfolios.csv`), and the `migrate-r6.swift` script. It still contains stale
  `[FIX]` items that R6 already resolved (e.g. C1 `InvestmentAccount`,
  C6 `BusinessEntity`→`Entity`, M3 entity reconciliation, M6 `Personal/Business`
  transactions). A build planned off a stale tracker will re-litigate settled
  decisions. *Gap-analysis severity: High.*

- **A2 — Prototype not updated to the R6 schema (P1).**
  `prototype/data.js` / `store.js` still use the old mock collections
  (`entities`, `holdings`, `deductions`) and lack liabilities, portfolios, and the
  new transaction fields (`group_id`, `group_role`, `liability_id`, `trade`/`credit`
  types). If the prototype is our primary review vehicle, the next review round
  cannot validate R6 against it until this is done. No roadmap task captures the
  work. *Gap-analysis severity: High.*

- **A3 — `technical-design.md` is a monolith; file-org proposal not executed (P2).**
  The proposed `docs/architecture/` split (`index.md`, `core-domain.md`,
  `containers-and-budgets.md`, `rulesets-and-taxes.md`, `data-pipelines.md`) was
  not created. The single file is becoming a bottleneck for review and diffing.
  Worth doing, but it is a refactor of *how* we document, not *what* we build —
  defer behind A1/A2. *Gap-analysis severity: Medium.*

- **A4 — No data-flow / ingestion pipeline diagrams (P2).**
  The import → normalize → `Transaction` → balance-update pipeline is the most
  complex path in the system and has no visual documentation. Pairs naturally with
  A3 (lives in `data-pipelines.md`). *Gap-analysis severity: Medium.*

- **A5 — Live market data not tracked anywhere (P2).**
  A forward-looking item with no home in the roadmap, PRD non-goals, or project
  tracker. It is already V1-out-of-scope ("Real-time market data"), so the action
  is simply to record it as a tracked V2 candidate so it isn't rediscovered cold.
  *Gap-analysis severity: Low.*

---

## B. Functional & semantic gaps (from `architectural-audit.md`)

- **B1 — Delete-on-reference behavior is still undecided (P0).**
  Both audits flag this, and the roadmap lists it as an Open Decision for Phase 6.
  But PRD §12 already commits us to delete for *every* user-addable object with a
  "reference check" — without defining what the check *does* (block / cascade-warn
  / reassign). Deleting an account or category with hundreds of linked transactions
  has no defined behavior. This is the single most load-bearing undefined V1
  semantic. Decide the default (and any per-object exceptions) this round; PRD §12
  and the roadmap Open Decision must agree. *Audit severity: High.*

- **B2 — Write/edit flows missing from the prototype (P1).**
  PRD §12 makes universal add/edit/delete a V1 requirement, but the prototype
  inspector is read-only and the documented write-preview / safe-write behavior is
  not demonstrated. This is a prototype-fidelity gap, not a spec gap — but for a
  data-entry app it is the core interaction we most need to review before build.
  Should become an explicit prototype task (pairs with A2). *Audit severity: High.*

- **B3 — Business: domain vs. theme ambiguity persists (P1).**
  The audit and `project-management.md` [FIX-C3]/[S2] both flag that Business is
  modeled inconsistently: Tech Design §11 lists `Business/BusinessEngine.swift`,
  but §12 assigns all business P&L to `AccountEngine`, and there is no standalone
  Business nav section or requirements block. R5/R6 leaned toward "business is a
  *group* under Accounts" (transactions inline, no sub-tabs), which suggests the
  files in §11 are vestigial. Pick one model and align §11/§12, the roadmap, and
  PRD §5 in one pass. *Audit severity: (structural).*

- **B4 — Markdown viewer scope still waffles (P1).**
  PRD §4 says "provide a readable native viewer in v1" while the out-of-scope list
  and roadmap defer the Notes viewer/editor to V2. `project-management.md` [FIX-S1]
  already names this. The likely intent — inline Markdown rendering in the right
  detail pane for linked tax/strategy notes is V1; a standalone Notes module is V2 —
  needs to be stated explicitly, with the supported Markdown subset (headers,
  tables, links) bounded to prevent scope creep. *Audit severity: (scope).*

---

## C. Architecture & execution risks (from `architectural-audit.md`)

- **C1 — iCloud concurrency / conflict resolution underspecified (P1).**
  The design names a "Conflict detected" UI state but does not specify how
  concurrent offline edits to a `transactions/YYYY-MM.csv` are resolved (the audit
  rates this High/High risk). Constitution principle #4 (Safe writes) demands
  atomic temp-file-then-rename and a conflict-winner flow. This intersects the
  Phase 1 `[DECIDE]` on the 7 iCloud sync states and the Phase 6 atomic-write
  temp-file location decision. Define the conflict model before Phase 6, ideally
  sketch it now since it shapes the write layer. *Audit severity: High.*

- **C2 — Re-index / file-watch performance at scale (P2).**
  Multi-year transaction history across dozens of CSVs could make full re-index a
  main-thread hazard on low-power Macs (audit: Medium/High). Mitigations —
  incremental parse, projection caching keyed by file hash, background parsing —
  are partly implied but should become explicit non-functional acceptance criteria
  (ties to the Phase 7 performance `[DECIDE]`). *Audit severity: Medium.*

- **C3 — Bootstrap / demo-data onboarding (P2).**
  Creating a ~20-file workspace from templates is heavy for a first run. A pre-filled
  demo dataset would de-risk first-use and double as the dev fixture
  (`fixture-generate.swift` already exists in the dev-loop notes). Improvement, not
  a blocker. *Audit severity: (improvement).*

- **C4 — `AccountEngine` monolith risk (P2).**
  Every engine depends on `AccountEngine`; the audit warns it could absorb Tax/
  Investment logic and become a bottleneck. CLAUDE.md already mandates building it
  first. The mitigation — keep it to read-only projection interfaces — should be a
  stated design constraint, not just folklore. *Audit severity: Medium.*

- **C5 — Tax scope creep guardrail (P2 — already mitigated).**
  Audit rates "tax logic expands into real calculation" High severity but Low
  likelihood; the PRD non-goal ("Tax return filing") and constitution already fence
  this. Action is to keep the guardrail explicit, not to change anything. *Audit
  severity: High / Low likelihood.*

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

## Proposed requirements updates — prioritized

This section translates the findings above into concrete edits, scoped primarily to
`docs/product-requirements.md` with the cascading doc each one touches. Ordered by
priority for principal review. (No edits applied yet — this is the proposal set.)

### P0 — resolve this round (blocks build / undefined core V1 behavior)

| # | Proposed requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 1 | **Define delete-on-reference behavior** and write it into PRD §12. Pick a default (recommend: *block + show referencing rows*, with explicit reassign/cascade only where it reads naturally). Resolve the matching roadmap Open Decision and `project-management.md` Phase 6 [DECIDE] to the same answer. | PRD §12 | technical-design (RepairService / write model), roadmap Open Decisions, project-management | B1 |
| 2 | **Re-sync `project-management.md` to the R6 object model.** Retire resolved [FIX] items (C1, C6, M3, M6, and any naming items R6 closed); add migration tasks for the three renames, `liabilities.csv` + `portfolios.csv`, and `migrate-r6.swift`. Not a PRD edit, but it gates an accurate build plan. | project-management | — | A1 |

### P1 — resolve this round or schedule explicitly (blocks a later phase)

| # | Proposed requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 3 | **Settle Business as group-under-Accounts vs. standalone module** and state it in PRD §5. Then align Tech Design §11/§12 (remove or formalize `BusinessEngine`) and the roadmap. | PRD §5 | technical-design §11/§12, roadmap, project-management [FIX-C3/S2] | B3 |
| 4 | **Bound Markdown scope in PRD §4**: inline rendering in the right detail pane is V1; standalone Notes module is V2; name the supported subset (headers, tables, links). | PRD §4 | roadmap (Notes V2), project-management [FIX-S1] | B4 |
| 5 | **Add a write-safety / conflict-resolution requirement** to PRD §1 and the Reliability NFR: atomic temp-then-rename, timestamped backup, and a user-driven conflict-winner flow for concurrent edits. | PRD §1 + NFR | technical-design (FileCoordinatorService, sync states), roadmap Phase 1/6 | C1 |
| 6 | **Add prototype tasks** to bring it to the R6 schema (A2) and to demonstrate write/edit/delete + write-preview (B2). Roadmap/tracker tasks, not PRD requirements. | roadmap / project-management | prototype/ | A2, B2 |

### P2 — track now, may defer

| # | Proposed requirement change | Primary doc | Cascades to | Source |
|---|---|---|---|---|
| 7 | **Add measurable performance acceptance criteria** (cold launch to first projection; full re-index of a realistic dataset; responsiveness during background re-index) to the Performance NFR. | PRD NFR | roadmap Phase 7 [DECIDE] | C2 |
| 8 | **State the `AccountEngine` read-only-projection constraint** as an explicit design principle. | technical-design §12 | CLAUDE.md architecture note | C4 |
| 9 | **Record bootstrap demo-data** as a first-run/onboarding requirement candidate (doubles as the dev fixture). | PRD §1 / roadmap Phase 1 | technical-design bootstrap | C3 |
| 10 | **Split `technical-design.md`** into `docs/architecture/` and add the ingestion **pipeline diagrams**. | technical-design | new docs/architecture/ | A3, A4 |
| 11 | **Track live market data** as an explicit V2 candidate in the roadmap out-of-scope list (already a V1 non-goal). | roadmap | PRD non-goals (reference) | A5 |
| 12 | **Keep the tax-scope guardrail explicit** — reaffirm "no tax-filing/calculation engine in V1" where write/tax requirements are described. | PRD §8 / non-goals | constitution (reference) | C5 |

### Recommended sequencing for the principal

1. Approve the two **P0** items (delete semantics decision + project-management re-sync) — these unblock everything else.
2. Confirm direction on the four **P1** items, especially the Business model (#3), since it has the widest doc cascade.
3. Triage **P2**: which become this-round update plans vs. tracked-for-later.

Once direction is set, I'll open `r7-update-product-requirements.md` (and cascading
`r7-update-technical-design.md` / `r7-update-product-roadmap.md`) per the doc-update
workflow.
