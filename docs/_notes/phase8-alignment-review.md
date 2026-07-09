# Phase 8 ↔ Code & Key-Docs Alignment Review

**Date**: 2026-07-07 · **Branch**: `009-out-of-scope-followups` (includes the onboarding /
`CloudDocsProvider` / packaging work) · **Scope**: every item in roadmap **Phase 8 — Out-of-Scope
Follow-ups** checked against the current `Sources/`+`Tests/` state and the key docs
(`docs/out-of-scope-followups.md`, `docs/project-management.md`, `docs/technical-design.md` §21,
`.specify/memory/constitution.md`, `DESIGN.md`, `docs/test-plans.md`).

**Method**: each claim in a Phase-8 row was re-verified directly in source (grep/read), not taken
from the docs that generated it. Evidence pointers are at the bottom.

**Verdict summary**: 13 of 15 rows **aligned**; 2 rows aligned but with **stale nuances** worth a
text refresh (OOS-5, OOS-22); 3 cross-doc **tensions** noted (project-management rule-catalog
wording, Phase-8 preamble vs the new PM grouping, `DomainRules.swift` header comment).

---

## 1 · Engine & read-model gaps (specs `004`/`005`/`006`)

| Item | Phase 8 says | Code reality | Alignment |
|---|---|---|---|
| **OOS-4** — investment/reinvested-gain retained equity | Split computed for the business portion only; extend in `PortfolioEngine`/`TaxEngine` | `retainedEquity` exists only in `AccountEngine` (aggregate + per-group); no retained-equity concept in `PortfolioEngine`/`TaxEngine` | ✅ Aligned |
| **OOS-5** — populate sleeve-funding links | Mechanism implemented; "yields links once investment trades exist in the ledger" | `LinkingEngine.sleeveLinks` is implemented and trades **do** exist since Phase 4 (`fixture-generate` emits `receiving_asset_id` rows) — but **nothing consumes** `SleeveFundingLink` outside `LinkingEngine`/`CrossDomainModels` | ⚠️ Aligned, text stale — the gap has moved from "no data" to "no consumer"; see §5.1 |
| **OOS-7** — itemized tax-archive read model | Parser skips `Taxes/archive/`; `TaxArchiveView` renders raw file previews | Confirmed: `ProjectionStore` excludes the archive path; `TaxesViewModel` lists archive files for raw preview | ✅ Aligned |
| **OOS-8** — account estimates surface | `AccountEstimate` has no `WorkspaceContext` accessor / projection | Confirmed: the type exists only in `AccountModels.swift`; no accessor, no engine output, panel shows rules only | ✅ Aligned |
| Per-account tax allocation | Effective rate from withholding legs; `estimated-payments.csv` feeds the estimate only | Confirmed in `TaxEngine.project` (withholding legs per account) | ✅ Aligned |

## 2 · Validation, repair & write-infra residue (specs `003`/`007`)

| Item | Phase 8 says | Code reality | Alignment |
|---|---|---|---|
| **OOS-2** — deferred `RepairService` repair classes | Optional-column injection, blank-field normalization, `WriteGate` gating of repair writes all pending | Confirmed: `.injectOptionalColumn` exists as an action kind but apply **skips it by design**; no blank-field logic; zero `WriteGate` references in `RepairService` | ✅ Aligned |
| **OOS-19** — six inert validation rules | `VAL-FILE-004`, `VAL-CROSS-009`, `VAL-DOMAIN-001/002/007/008` are catalog metadata with no predicate | Confirmed: all six registered in `RuleCatalog`, none wired in `Rules/*.swift`; they can never fire | ✅ Aligned (see §5.2 for a doc tension) |
| **OOS-22** — per-file sync states never reach the write gate | `applyPendingWrite` passes `fileStates: [:]`; per-file refusals inert | Still true — **and this branch widened it**: `onboardingApply` is a second `fileStates: [:]` call site. Counterweight: `CloudDocsProvider.syncState(for:)` now supplies real per-file states **without an entitlement**, making the fix exercisable pre-signing | ⚠️ Aligned, text predates branch; see §5.3 |

## 3 · Code-audit findings (2026-07-06) + QA residue

| Item | Phase 8 says | Code reality | Alignment |
|---|---|---|---|
| **OOS-20** — transfer authoring | `TransactionGroupEditor` is paycheck-only; `MultiEntryLeg.Role` lacks credit/debit | Confirmed — recorded in the view's own header comment; unchanged by this branch (onboarding did not touch multi-entry) | ✅ Aligned |
| **OOS-21** — generic current-view export | ⌘E exports the module's primary file; visible-rows export missing | Confirmed: `ExportService` has `csv(rows:columns:)` (arbitrary rows) + `budgetSummaryMarkdown`; no view-side visible-rows plumbing | ✅ Aligned |
| **OOS-23** — hardcoded tax tables | 2025/2026 only, silent latest-year fallback; ties to the open Phase-4 `[DECIDE]` | Confirmed in `WorkspaceLayout.standardDeduction`/`taxBrackets`; the `[DECIDE]` (hardcode vs setting) is still open in `docs/project-management.md` | ✅ Aligned |
| **OOS-24** — interest-income heuristic | Category-name `contains("interest")` | Confirmed in `TaxEngine.project` | ✅ Aligned |
| Flow 9 manual demo pass | `[Manual pass pending]` in `docs/test-plans.md` | Confirmed at Flow 9's heading; automated proofs recorded as passed | ✅ Aligned |

## 4 · PM-requested enhancements (added 2026-07-07)

| Item | Phase 8 says | Code reality | Alignment |
|---|---|---|---|
| Sidebar re-ordering of accounts/groups | Feature absent; persist as optional `sort_order` columns | Confirmed: `sort_order` appears **nowhere** in `Sources/` or the bundled schemas; `NavigationSidebarView` has no ordering affordance — order comes from projection order | ✅ Aligned (genuinely new work) |
| Delete inside the edit modal | `EntityEditForm` is save/cancel only; delete lives at the detail-pane bottom | Confirmed: no delete in `EntityEditForms.swift`; `DetailPaneView` hosts the only Delete button (`requestDelete`), per the FR-010 placement convention | ✅ Aligned (genuinely new work) |

---

## 5 · Discrepancies & suggested text refreshes

1. **OOS-5 is half-resolved and its rationale is stale.** The roadmap/OOS text still explains the
   empty links by "no trades in the ledger" — that was Phase-3 reality. Since Phase 4, trades with
   `receiving_asset_id` exist (fixtures included), so `sleeveLinks` presumably yields links today;
   the real remaining gap is that **no projection or view consumes `SleeveFundingLink`** (the
   Portfolio sleeve table's "contribution target" doesn't read it). Suggest rewording OOS-5 to
   "surface sleeve-funding links in `PortfolioEngine`/`PortfolioView`" when it's next touched.
2. **`docs/project-management.md` overstates the rule catalog.** Its resolved `[DECIDE]` says the
   catalog of 34 rules "is implemented … confirmed by the Milestone 2 gate." OOS-19 shows six of
   the 34 are metadata-only (no predicate). The catalog *entries* exist, so the sentence is
   defensible, but a reader would assume the rules fire. Worth a one-line annotation pointing at
   OOS-19 next time that doc is edited.
3. **OOS-22 text predates this branch.** Two updates when next touched: (a) `onboardingApply`
   (`AppState+Onboarding.swift`) is a second `fileStates: [:]` call site; (b) `CloudDocsProvider`
   now provides real per-file states without the entitlement, so the fix no longer waits on the
   signed build — the Phase-7 "would otherwise pass trivially" warning applies to the CloudDocs
   distribution too.
4. **Phase-8 preamble vs contents.** The preamble still says Phase 8 holds only "residue of
   Phases 1–6" / "v1-adjacent residue only," but the phase now also carries *Code-audit findings*
   and *PM-requested enhancements* groupings. The grouping titles make the provenance clear;
   suggest softening the preamble sentence on the next roadmap edit rather than restructuring.
5. **`DomainRules.swift` header comment is wrong** (claims DOMAIN-003/004 pending; both are
   implemented in that file). Already folded into OOS-19's task text — just don't fix the comment
   without also checking the OOS-19 row, or the docs will point at a ghost.
6. **PM rows intentionally absent from `docs/out-of-scope-followups.md`.** That doc defines itself
   as *spec residue*; the two PM enhancements are new feature asks, so they live only in the
   roadmap. This is deliberate, but it means the Phase-8 preamble's "canonical list =
   out-of-scope-followups.md" is now true for residue rows only.

## 6 · Key-doc cross-check

| Doc | Checked against | State |
|---|---|---|
| `docs/out-of-scope-followups.md` | Roadmap Phase 8 rows | ✅ In lockstep for all OOS-numbered rows (2, 4, 5, 7, 8, 19–24); OOS-13…18 correctly tagged Phase 7 in both |
| `docs/project-management.md` | OOS-19, OOS-23 | ⚠️ Rule-catalog wording (§5.2); the standard-deduction `[DECIDE]` is open and correctly cross-referenced by OOS-23 |
| `docs/technical-design.md` §21 | Phase-8 items touching locked decisions | ✅ No Phase-8 item reopens a lock; the 2026-07-06 CloudDocs amendment is recorded as additive |
| `.specify/memory/constitution.md` | Sidebar re-ordering + edit-modal delete rows | ✅ Both rows cite the right principles (plain-files-first persistence; safe-write + reference-checked delete) |
| `DESIGN.md` | Phase-8 UI-touching rows (re-ordering, delete-in-modal, OOS-20/21) | ✅ No conflicts; all four will need the design-adherence gate at build time (delete-in-modal follows the locked "delete inside the edit flow" convention) |
| `docs/test-plans.md` | Flow 9 row | ✅ Matches (`[Manual pass pending]`) |

## 7 · Evidence pointers

- OOS-4: `Domain/Accounts/AccountEngine.swift:122,227` (only `retainedEquity` sites in the Kit)
- OOS-5: `Domain/CrossDomain/LinkingEngine.swift:19-25`; consumer grep hits only `CrossDomainModels.swift`
- OOS-7: `ProjectionStore.swift:92`; `UI/Taxes/TaxesViewModel.swift:153-159`
- OOS-8: `AccountEstimate` referenced only in `Domain/Accounts/AccountModels.swift`
- OOS-2: `Validation/RepairService.swift` (header doc + `.injectOptionalColumn` → `.skipped`; no `WriteGate` refs)
- OOS-19: `Validation/RuleCatalog.swift:15,36,40,46,47`; `Validation/Rules/DomainRules.swift:5`
- OOS-22: `AppState+WriteFlows.swift:51`; `AppState+Onboarding.swift` (`onboardingApply`); `Platform/CloudDocsProvider.swift` (`syncState(for:)`)
- OOS-20: `UI/Write/TransactionGroupEditor.swift:9-11`
- OOS-21: `Persistence/Write/ExportService.swift:27,41`
- OOS-23: `Platform/WorkspaceLayout.swift:130-139`; `docs/project-management.md` (open `[DECIDE]`, standard-deduction seeding)
- OOS-24: `Domain/Taxes/TaxEngine.swift:20-24`
- Re-ordering: `sort_order` absent from `Sources/` + `Resources/Schemas/`; `UI/Shell/NavigationSidebarView.swift` (no ordering affordance)
- Delete-in-modal: `UI/Write/EntityEditForms.swift` (no delete); `UI/Shell/DetailPaneView.swift:44` (`requestDelete`)
