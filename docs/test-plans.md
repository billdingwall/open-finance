# Manual Test Plans

How to manually test Open Finance at its current stage, what is and isn't testable yet, and
the specific user flows to exercise to surface bugs.

> **Workflow:** as each Spec Kit spec is implemented, this doc is updated to reflect the current
> **app testability status** and the user flows the new work makes testable. The product manager
> reviews testability against app completeness and manually tests specific user flows. For the
> underlying build/run commands see
> [`docs/_notes/running-and-testing.md`](_notes/running-and-testing.md).
> Last updated: 2026-06-30 (end of Phase 2).

### Where "expected behavior" is specified

When a flow below surprises you, check it against the source of truth before logging it as a bug:

| For feedback on… | See |
|---|---|
| What the app *should* do (modules, scenarios, functional requirements) | [`docs/product-requirements.md`](product-requirements.md) |
| Workspace folder/file layout and every CSV/MD column spec | [`docs/architecture/containers-and-budgets.md`](architecture/containers-and-budgets.md) |
| Validation rules and repair behavior | [`docs/architecture/rulesets-and-taxes.md`](architecture/rulesets-and-taxes.md) · [`docs/architecture/data-pipelines.md`](architecture/data-pipelines.md) |
| Architecture, locked decisions, layer model | [`docs/technical-design.md`](technical-design.md) |
| Non-negotiable principles every flow must honor | [`.specify/memory/constitution.md`](../.specify/memory/constitution.md) |

---

## 1. Testability status

### 🔴 Not ready for end-user app testing

**There is no usable application to open and use yet.** A non-developer cannot install Open
Finance, open it, and exercise budgeting/accounts/taxes the way the product is meant to work.
The native macOS app — the real window, sidebar navigation, and module views — is **Phase 5**
and has not been built. What ships today is a Swift Package whose `FinanceWorkspaceApp` target
is a **minimal diagnostic shell**: a single window that resolves the workspace and prints
availability, sync state, and the workspace path. It has no charts, tables, navigation, create
or edit flows, or detail panes.

### What *is* testable right now

Even though the app isn't usable, three layers underneath it can be exercised and given
feedback on today:

| Area the user wants to evaluate | Testable now? | How |
|---|---|---|
| **How flat files are organized** | ✅ Yes | Provision a workspace and inspect the `Finance/` folder in Finder, Numbers, or a text editor |
| **How the app *looks*** | ✅ Yes (intended design) | Open the static `prototype/` in a browser — it mirrors the planned UI |
| **Parsing / validation / repair behavior** | ✅ Yes | Run the `validate-workspace` / `repair-workspace` / `migrate-r6` CLIs |
| **Local workspace provisioning & file index** | ✅ Yes | Run `bootstrap-workspace` / `fixture-generate` / `index-check` |
| **Accounts / Budget / Overview projections** | ✅ Yes (Phase 3) | Run `accounts-overview` / `budget-overview` / `overview-dashboard` against a fixture (`--as-of`/`--period` for deterministic output) |
| **How the real app functions** | ❌ No | Blocked on the Phase 5 SwiftUI presentation layer (the domain read model now exists) |
| **How well iCloud syncing works** | ❌ No | Blocked — needs an Xcode app target + iCloud entitlement (Phase 5) |

So: feedback on **file organization**, the **intended look** (via prototype), and the
**read/validate/repair pipeline** is valuable now. Feedback on the **living app** and on
**real iCloud syncing** has to wait for later phases.

---

## 2. How to test (and what dev work unblocks full testing)

### A. Prerequisites

- macOS 15 (Sequoia)+
- Swift 6 toolchain (`swift --version`)
- A modern browser (for the prototype)
- Full Xcode 16 only if you also want to run `swift test`

A quick build confirms the toolchain:

```bash
swift build      # expect: Build complete!
```

### B. Test the flat-file workspace (file organization + read pipeline)

This is the most valuable testing available today and maps directly to the "how are the flat
files organized" and "how does parsing/validation work" feedback goals.

```bash
# 1. Seed a real, valid workspace
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance

# 2. (Optional) generate a fuller fixture with sample transactions
swift run fixture-generate --workspace ~/Finance-Dev --months 12

# 3. Inspect the result in Finder
open ~/Finance-Dev/Finance

# 4. Scan + summarize the index
swift run index-check --workspace ~/Finance-Dev/Finance

# 5. Parse + validate (issues by severity; exit 1 on errors)
swift run validate-workspace --workspace ~/Finance-Dev/Finance

# 6. Preview, then apply, deterministic repairs
swift run repair-workspace --workspace ~/Finance-Dev/Finance --dry-run
swift run repair-workspace --workspace ~/Finance-Dev/Finance --apply
```

Open each CSV in Numbers/Excel or a text editor and judge the **folder layout, file naming, and
column structure** — this is exactly the source-of-truth the app is an interface over.

### C. Review the intended look & feel (prototype)

The static prototype is the stand-in for the not-yet-built app UI. Use it to give feedback on
visual design, layout, and the *intended* interaction model.

```bash
open prototype/index.html
```

It opens on Accounts; navigate via the left sidebar. **Settings › Workspace › Prototype Review
Controls** lets you simulate onboarding, cycle sync states, show indexing, and reset data. See
[`prototype/README.md`](../prototype/README.md) for the reviewer session guide. Note this is a
browser mock, not the real app — buttons that would trigger native macOS actions show an
explanatory toast instead.

### D. Dev work required to reach "ready for app testing"

Full end-user app testing (open the app, click through real budgeting/accounts/taxes, observe
real iCloud sync) is blocked until the following land, in order:

| Blocker | Phase | Unblocks |
|---|---|---|
| Domain engines I — Accounts, Budget, Overview | Phase 3 | Real numbers/projections behind any view |
| Domain engines II — Savings, Investments, Tax | Phase 4 | Remaining module data |
| **Xcode app target + module views (real UI)** | Phase 5 | Opening and using the app at all |
| iCloud entitlement on a signed build | Phase 5 | Testing real cross-device sync |

Until Phase 5, the app surface is the diagnostic shell only, and "sync" is exercised through the
local-folder provider, not iCloud.

---

## 3. User flows to test (to surface bugs)

Each flow below is testable **now** unless marked **[Blocked]**. Run them against a fresh
workspace and a 12-month fixture, and note anything surprising — wrong files, confusing
structure, false-positive validation, non-idempotent repairs, or layouts that don't match the
product intent.

Each flow names the constitution principle it exercises, so feedback can be tied back to a
non-negotiable. The principles: **(1)** plain files first · **(2)** read model second
(regenerable) · **(3)** native over generic · **(4)** safe writes only · **(5)** traceability
always · **(6)** cross-domain visibility · **(7)** repair when safe.

### Flow 1 — First-run provisioning (file organization) · principle 1

1. Run `bootstrap-workspace` against an empty path.
2. In Finder, confirm the `Finance/` tree matches the documented layout: `Accounts/`,
   `Budget/`, `Savings/`, `Investments/`, `Taxes/`, `Notes/`, `.finance-meta/`.
3. Open several CSVs and the `Workspace.md`. **Judge:** Are folder/file names intuitive? Are
   columns understandable to a human editing them by hand?
4. Re-run `bootstrap-workspace` on the same path. **Expect:** idempotent — no edits overwritten,
   no duplicate files.

### Flow 2 — Index integrity & resilience · principle 2

1. `index-check --workspace … --save`. **Expect:** `error records: 0`,
   `.finance-meta entries (must be 0): 0`.
2. Re-run. **Expect:** identical hashes (deterministic, regenerable).
3. Make one transactions file unreadable (`chmod 000`), re-run. **Expect:** that file becomes
   one error record; all others still index. Restore with `chmod 644`.
4. Delete the manifest from `~/Library/Application Support/OpenFinance/…` and re-scan.
   **Expect:** it rebuilds cleanly (manifest is a cache, never source of truth).

### Flow 3 — Validation on a clean workspace (false-positive hunt) · principle 5

1. `validate-workspace` on the freshly bootstrapped workspace. **Expect:** zero errors and
   **zero false-positive warnings** — a clean workspace must look clean.
2. `validate-workspace --json --report /tmp/validation.json` on the 12-month fixture. **Expect:**
   one unified result grouped by severity; spot-check that issue IDs follow `VAL-<TIER>-<NNN>`.

> **Performance caveat:** a full parse + validate of the 12-month fixture should feel
> responsive (SC-002 is a *soft* target at this stage; hard thresholds and the Apple-Silicon
> performance baseline are deferred to roadmap Phase 7). Note sluggishness as an observation,
> not a failing test.

### Flow 4 — Validation on a broken workspace (detection) · principles 5, 6

1. Hand-edit a CSV to introduce defects: a bad date, a bad decimal, an unknown enum value, a
   missing required column, a transaction referencing a non-existent `account_id`.
2. Re-run `validate-workspace`. **Expect:** each defect surfaces as a classified issue with the
   right severity; a bad *field* yields a **partial record** (a single file-level issue), not a
   dropped row and not a crash.
3. **Judge:** Are the messages clear enough for a human to know what to fix?

### Flow 5 — Repair preview & apply (safe-write contract) · principles 4, 7

1. Introduce an auto-repairable defect (missing optional column / missing seed file / missing
   folder / header casing).
2. `repair-workspace --dry-run`. **Expect:** a readable before/after diff, **no writes**.
3. `repair-workspace --apply`. **Expect:** defect fixed, a timestamped backup created, and a new
   row in `.finance-meta/logs/repair-log.csv`.
4. `repair-workspace --apply` again. **Expect:** no-op (idempotent). Confirm **manual-only**
   issues were left untouched.

### Flow 6 — Legacy (pre-R6) migration · principles 1, 4

1. Create or obtain a pre-R6 workspace (old file/column names, separate
   `Investments/transactions.csv`).
2. `migrate-r6 --dry-run`. **Expect:** a change plan, no writes.
3. `migrate-r6 --apply`. **Expect:** files/columns renamed, investment trades folded into the
   unified ledger as trade rows, new R6 files seeded, `schema_version` bumped — losslessly.
4. Re-run `--apply`. **Expect:** no-op on an already-R6 workspace.

### Flow 7 — Diagnostic app shell · principle 3

1. `swift run FinanceWorkspaceApp` (debug → local-folder provider, no iCloud).
2. **Expect:** the window resolves/provisions the workspace and shows availability, sync state,
   and path. A pre-R6 workspace shows a migration notice (never auto-migrates).
3. This verifies wiring only — there is no usable UI to test beyond these labels.

### Flow 8 — Intended UX review (prototype) · principle 3

1. `open prototype/index.html`; walk every section: Overview, Accounts, Budget, Savings &
   Investments, Taxes, Settings.
2. Exercise the Prototype Review Controls (onboarding, sync-state cycle, indexing).
3. **Judge:** Does the visual design, information architecture, and intended interaction feel
   right? Capture this as design feedback — it informs the Phase 5 build.

### Blocked flows (revisit at Phase 5)

- **[Blocked]** Open the real app and navigate module views with live data.
- **[Blocked]** Create/edit/delete records through the app and confirm safe writes to disk.
- **[Blocked]** Real iCloud sync: edit on one device, observe sync state and the update on
  another; conflict resolution.

---

## Appendix — command reference

```bash
swift build
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance
swift run fixture-generate    --workspace ~/Finance-Dev --months 12
swift run index-check         --workspace ~/Finance-Dev/Finance --save
swift run validate-workspace  --workspace ~/Finance-Dev/Finance
swift run repair-workspace    --workspace ~/Finance-Dev/Finance --dry-run
swift run migrate-r6          --workspace ~/Finance-Dev/Finance --dry-run
swift run FinanceWorkspaceApp
open prototype/index.html
```
