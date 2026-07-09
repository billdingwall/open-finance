# Product Backlog

**Created**: 2026-07-07 (renamed and rewritten from `docs/project-management.md` — the phase-based
`[FIX]`/`[DECIDE]` tracker that document was is retired now that Phases 1–7 are built or in flight;
its full item history is preserved in git)
**Last updated**: 2026-07-07
**Sources**: roadmap **Phase 8** (closed 2026-07-07 — all rows triaged here;
verification: [`docs/_notes/phase8-alignment-review.md`](_notes/phase8-alignment-review.md)),
the 2026-07-07 review of the old tracker's open items, and PM requests.

---

## How this backlog is prioritized

1. **Add user value** is the top tier. **Security & performance** and **Visual design updates**
   are equally weighted behind it.
2. Within each tier, items are ordered by **level of effort, smallest first**
   (S ≈ hours, M ≈ days, L ≈ a spec of its own).
3. Every backlog item must be inline with
   [`docs/product-requirements.md`](product-requirements.md) and
   [`docs/technical-design.md`](technical-design.md) (+ `docs/architecture/`). Items that are not
   sit at the bottom under **Under consideration** until they're reconciled or dropped.
4. Items promoted into a build go through the normal Spec Kit flow (`/speckit-specify` …); UI
   items clear the `design-adherence` gate at build time.
5. **Growth process (since 2026-07-09)**: this backlog is the sole source of forward work. The PM
   promotes items into the **Growth → Readying** table in
   [`docs/product-roadmap.md`](product-roadmap.md); each ships spec-first on its own `NNN-` branch;
   on merge the roadmap row moves to *Delivered* and the backlog row closes. Implementation residue
   flows through `docs/out-of-scope-followups.md` straight back into this backlog.

**ID scheme**: `UV-` user value · `SP-` security & performance · `VD-` visual design ·
`UC-` under consideration. Prior `OOS-n` provenance is kept in the Source column.

---

## 1 · Add user value

> PM directive 2026-07-07: **UV-1 and UV-2 lead the backlog** — direct user value. The rest of the
> tier is effort-ordered.

| ID | Item | Source | Effort | Notes |
|---|---|---|---|---|
| **UV-1** | **Manual re-ordering of accounts & account groups in the sidebar** — drag-reorder groups and the accounts within them in `NavigationSidebarView`; persist as optional `sort_order` columns on `accounts.csv`/`account-groups.csv` (plain-files-first, additive/non-breaking); reorder writes via the safe-write path; absent values keep today's default order; card grids mirror sidebar order | PM request 2026-07-07 | M | Needs a small PRD/schema amendment when specced (`sort_order` isn't in the PRD/TDD yet — PM has prioritized it regardless) |
| **UV-2** | **Delete inside the edit modal** for accounts, account groups, and categories — `EntityEditForm` gains a destructive Delete action ("delete inside the edit flow" per the locked R5 convention), routed through `requestDelete` → `ReferenceScanner` → atomic delete+reassignment plan → write preview; never a bare row delete | PM request 2026-07-07 | S | Overlaps OOS-14 (Phase 7); benefits from the OOS-17 reassignment picker (Phase 7) |
| UV-3 | **Export the current view (visible rows)** — ⌘E currently exports the active module's primary file; export the *visible* (filtered/sorted) rows of any table instead. `ExportService.csv(rows:columns:)` already accepts arbitrary rows — view-side plumbing only | OOS-21 (007 FR-027 residue) | S | |
| UV-4 | **Surface account estimates** — add a `WorkspaceContext` accessor + engine projection for `AccountEstimate` so the per-account "Rules & estimates" panel shows estimates, not just rules | OOS-8 (006 FR-019) | S–M | Pairs with the Phase-7 rules/estimates edit flows |
| UV-5 | **Surface sleeve-funding links** — `LinkingEngine.sleeveLinks` computes and trades exist since Phase 4, but nothing consumes `SleeveFundingLink`; feed it into `PortfolioEngine`/`PortfolioView` (sleeve table contribution tracking) | OOS-5 (004 FR-015) *(reworded per the alignment review — the gap is a missing consumer, not missing data)* | M | |
| UV-6 | **Transfer authoring in the multi-entry editor** — `TransactionGroupEditor` ships paycheck groups only; add credit/debit roles to `MultiEntryLeg.Role` (small additive engine change) + a transfer mode in the editor | OOS-20 (008 T018 deviation) | M | |
| UV-7 | **Typed tax-archive read model** — the parser skips `Taxes/archive/`, so closed years render as raw file previews; add a parser/engine extension for typed adjustment/payment tables in `TaxArchiveView` | OOS-7 (006 FR-029) | M | Or close as won't-do if raw previews suffice — PM call at spec time |
| UV-9 | **Workspace reset + fresh-or-seeded onboarding** — a "Reset workspace…" action that wipes the iCloud workspace folder and relaunches the first-run wizard; onboarding Step 1 gains a choice: **start fresh** (standard bootstrap seed) or **start with sample data** (a fixture-generate-style 12-month demo dataset). Destructive: typed confirmation + an automatic pre-wipe archive of the old folder (safe-writes principle — never an unrecoverable wipe); must also clear device-local state (manifest, onboarding-complete flag) so the wizard re-triggers | PM request 2026-07-09 | M | Needs a small PRD amendment (no reset flow is specced); the sample-data path reuses `fixture-generate`'s generator via the Kit |
| UV-8 | **Investment/reinvested-gain retained equity** — extend the personal-inflow vs retained-equity split beyond the business portion: `PortfolioEngine`/`TaxEngine` compute retained equity from reinvested realized gains now that trades are modeled | OOS-4 (004 FR-001/A1) | L | Cross-engine; spec of its own |

## 2 · Security & performance

*(Equal weight with §3 — both rank behind §1.)*

| ID | Item | Source | Effort | Notes |
|---|---|---|---|---|
| SP-1 | **Flow 9 manual demo pass** — run the Milestone-5 interactive walkthrough (`docs/test-plans.md` Flow 9: keyboard nav, dark mode, traceability); automated proofs already passed | 006 T063 (QA residue) | S | May be absorbed by the Phase-7 XCUITest + quickstart runs |
| SP-2 | **Replace the interest-income name heuristic** — `TaxEngine` matches categories by `name.contains("interest")`; renamed/non-English categories silently drop interest from the tax projection. Typed category flag (schema round) or documented convention + validation rule | OOS-24 (code audit) | S | |
| SP-3 | **Tax tables: coverage + fallback warning** — `WorkspaceLayout.standardDeduction`/`taxBrackets` are hardcoded for 2025/2026 with a silent latest-year fallback; decide hardcode-per-year vs user-editable setting (the old Phase-4 `[DECIDE]`, still open — now this row), add an annual update procedure and a "no tax table for year N" validation warning | OOS-23 (code audit) | S–M | |
| SP-4 | **Wire the six inert validation rules** — `VAL-FILE-004`, `VAL-CROSS-009`, `VAL-DOMAIN-001/002/007/008` are catalog metadata with no predicate (can never fire); write the predicates + tests; fix the stale `DomainRules.swift` header comment; DOMAIN-002 may close as covered by CROSS-008 | OOS-19 (003 T023–T025) | M | |
| SP-5 | **Deferred `RepairService` repair classes** — optional-column injection (needs an "expected columns" notion), blank-field normalization, and `WriteGate` sync-gating of repair writes (FR-016a) | OOS-2 (003 T030) | M | |
| SP-7 | **Verify `NSUserActivity` restoration in the signed app** — the deep-link codec + `AppRouter.resolve` nearest-valid fallback are implemented and unit-tested, but OS-level window restoration only exercises inside a signed, bundled app (the SwiftPM executable has no runtime `NSUserActivityTypes` registration). Run the check on a Developer-ID-signed install; restore to the nearest valid context when the prior entity is gone | OOS-9 / 008 T042 (the one 008 task left open) | S | Blocked on the Developer ID certificate; bundle with the Flow 10 two-device pass and the first signed build |
| SP-8 | **First signed release** — the Developer ID signing + notarization RUN on the entitled app target (config + procedure landed: `App/project.yml` Release settings, `docs/_notes/running-and-testing.md` §7), the **two-device iCloud sync + conflict exercise** (`docs/test-plans.md` Flow 10), and the **release notes / known-limitations** doc (iCloud edge cases). Absorbs the last open Phase-7 roadmap tasks | Roadmap Phase 7 (Packaging & Signing + release-notes product task) | S–M | **Blocked on the Developer ID certificate** ($99 Apple Developer account — developer-machine action). Bundle with SP-7; the SwiftPM/CloudDocs path (`scripts/package-release.sh`) shares the same credentials |
| SP-9 | **Run XCUITest in CI** — the `FinanceWorkspaceUITests` target + `ModuleSmokeUITests` exist and build; add an `xcodebuild test -scheme FinanceWorkspace` step to `.github/workflows/ci-macos.yml` so the smoke suite executes on the macOS runner | 008 T056 caveat | S | |
| SP-10 | **CLI parity: `import-csv` + `export-summary` executables** — the planned dev-tool twins of the in-app flows were never built: an `import-csv` CLI (external CSV → column map → month-split canonical ledgers) and an `export-summary` CLI (budget Markdown / provenance CSV). Both wrap existing, tested Kit engines (`ImportMapper`, `ExportService`) — thin `main.swift` wrappers + `Package.swift` targets | Roadmap Phase 6 dev tasks (unchecked, undelivered — found in the 2026-07-09 MVP sweep) | S | |
| SP-6 | **Per-file sync states → write gate** — the app calls `WriteService.apply(…, fileStates: [:])` from both `applyPendingWrite` and `onboardingApply`, and unknown files default to `.available`, so `WriteGate`'s per-file refusals (syncing/stale/conflict) can never fire. Thread real per-file states through `AppState`; `CloudDocsProvider.syncState(for:)` now supplies them **without an entitlement**, so this no longer waits on the signed build | OOS-22 (code audit) *(reworded per the alignment review)* | M | Pairs with VD-1 (per-file badges) and the Phase-7 signed-build sync tests, which pass trivially until this lands |

## 3 · Visual design updates

*(Equal weight with §2 — both rank behind §1.)*

| ID | Item | Source | Effort | Notes |
|---|---|---|---|---|
| VD-1 | **Per-file sync badges (7 states)** — design + implement the per-file sync badge treatment (the workspace-level chip shipped in Phase 5; the per-file badge is the unresolved residue of the Phase-1 sync-indicator `[DECIDE]`) | Phase-1 design residue | S–M | Depends on SP-6 for live per-file state |
| VD-2 | **Onboarding wizard prototype mock** — add the `onboarding-wizard` + `step-indicator` components (DESIGN.md v1.2) to `prototype/` so the living reference matches the shipped app | DESIGN.md v1.2 changelog note | S | |
| VD-3 | **Final iconography pass** — section icons, status icons, issue-severity icons, account-group icons consistent and at correct scale (the one Phase-7 design `[DECIDE]` not folded into spec 008) | Phase-7 design task | M | |
| VD-4 | **Designed app icon** — replace the generated placeholder (`scripts/make-icon.swift`) with a designed icon for the distributable app | Packaging scripts note | M | Coordinate with VD-3 |
| VD-5 | **iCloud folder cleanup + app-icon branding** — tidy the user-visible workspace tree (today the CloudDocs path nests iCloud Drive › OpenFinance › Finance — decide whether that flattens) and brand the folder with the app icon. Entitled-container path: declare `NSUbiquitousContainers` (public document scope + container display name) so iCloud Drive shows the app's branded folder natively; CloudDocs path: custom folder icon via `NSWorkspace.setIcon` (local-only — resource forks don't sync over iCloud Drive) | PM request 2026-07-09 | S–M | Structure changes touch `WorkspaceLayout` + both providers — check against the §21 locked layout; icon asset comes from VD-4 |

## Under consideration

*(Not currently inline with the PRD/TDD, or explicitly not committed — reconcile or drop before
promoting.)*

| ID | Item | Why it's here |
|---|---|---|
| UC-1 | **Per-account tax allocation precision** — `TaxEngine` effective rate uses ledger withholding legs; `estimated-payments.csv` is workspace-level and feeds the estimate only. Precision would need an account-allocation model (schema + engine) | Explicitly "acceptable for v1" (spec 005); no PRD requirement for per-account payment allocation — needs a product decision first |
| UC-2 | **Doc-consistency pass: PRD data-model naming (`[FIX-M3]`)** — the PRD data-model table still carries legacy entity names (`Lot`, `Position`, `BenchmarkSeries`, `RealizedGain`, `IncomeEvent`, `MonthlyReview`, …); reconcile to the canonical names in `docs/architecture/core-domain.md §1`, and remove the now-stale entity-naming note at `core-domain.md §1` (it points at a TDD §10 listing that the R7 refactor replaced with a pointer) | The item *is* a PRD/TDD misalignment — it can't be "inline" by definition until done |
| UC-3 | **Doc-consistency pass: PRD architecture language (`[FIX-M4]`)** — PRD §Technical still recommends "MVVM for presentation logic"; the shipped app is `@Observable`-based (TDD §11). Update the PRD wording | Same — the misalignment is the work |

---

## Closed in the 2026-07-07 review

Items from the old tracker verified closed against the repo during the rename (evidence:
`docs/_notes/phase8-alignment-review.md` + the review pass):

- **First-launch onboarding flow** `[DECIDE]` → shipped 2026-07-06 on `009-out-of-scope-followups`
  (3-step wizard, require-iCloud with retryable failure states; DESIGN.md v1.2).
- **Loading/indexing state** + **global app shell skeleton** `[DECIDE]`s → shipped in Phase 5
  (`LoadingSkeletonView`, the full `NavigationSplitView` shell).
- **Workspace sync status indicators** `[DECIDE]` → workspace-level chip shipped in Phase 5;
  the per-file badge residue is now **VD-1**.
- **`[FIX-C6]`, `[FIX-M1]`, `[FIX-M6]`** → overtaken by the R7 lean refactor: TDD §10/§11 are now
  pointers into `docs/architecture/core-domain.md`, which uses the canonical names; no
  `BusinessEntity`/`PersonalTransaction` listing or conflicting layer count remains in the TDD.
  (The PRD side lives on as **UC-2**/**UC-3**; the stale cross-reference note in
  `core-domain.md §1` is folded into UC-2.)
- **Phase-7 `[DECIDE]`s** (5 of 6) → resolved by spec `008-polish-launch`: performance acceptance
  criteria (clarify: ≤2s cold-launch, ≤5s re-index), accessibility + dark-mode audits (US5,
  WCAG AA), responsive layout (US5), onboarding polish (T045 + the shipped wizard). The sixth —
  final iconography — is now **VD-3**.
- **Phase 2–6 historical `[FIX]`/`[DECIDE]` records** → all were already resolved in place; their
  full text and resolutions are preserved in this file's git history
  (`docs/project-management.md` prior to 2026-07-07).

## Changelog

- **2026-07-09 (MVP sweep)** — Added **SP-10** (CLI parity: `import-csv` + `export-summary`
  executables) — the single genuinely-undelivered, untracked item found when sweeping every
  unchecked checkbox in the roadmap's MVP record before condensing it to prose; every other
  unchecked box was either delivered (per-phase banners) or already had a backlog row.
- **2026-07-09 (Growth)** — Project entered the **Growth phase**: this backlog is now the sole
  source of forward work (prioritization rule 5 above). Added **SP-8** (first signed release —
  sign+notarize run, two-device Flow 10, release notes; absorbs the last open Phase-7 roadmap
  tasks, certificate-gated) and **SP-9** (execute XCUITest in CI). Placement note: like SP-7,
  SP-8 groups with the signed-build actions rather than strictly by effort.
- **2026-07-09** — Added **UV-9** (workspace reset + fresh-or-seeded onboarding — wipe the iCloud
  folder behind a typed confirmation + pre-wipe archive, re-run the wizard with a start-fresh vs
  start-with-sample-data choice) and **VD-5** (iCloud folder structure cleanup + app-icon
  branding: `NSUbiquitousContainers` for the entitled container, `NSWorkspace.setIcon` for
  CloudDocs). UV-9 is slotted by effort (M) ahead of UV-8 (L) — IDs are stable, table order is
  priority.
- **2026-07-09** — Added **SP-7** (verify `NSUserActivity` restoration in the signed app — OOS-9 /
  008 T042, the one spec-008 task left open after PR #23 went green; blocked on the Developer ID
  certificate). Ordering note: SP-7 sits with the other signed-build actions rather than strictly
  by effort.
- **2026-07-07** — Created from `docs/project-management.md`: closed the stale open items (above),
  reformatted as a prioritized backlog (user value → security & performance ∥ visual design →
  under consideration; effort-ordered within tiers), and merged all verified roadmap **Phase 8**
  items (OOS-2/4/5/7/8/19–24 + QA residue + the two PM requests, which lead the backlog).
  Phase 8 is closed in `docs/product-roadmap.md`; OOS-5 and OOS-22 were merged with the corrected
  wording from the alignment review.
