# Architecture Files Update Plan — Round 7

Source: `docs/_refinement/r7-review.md` (MVP prep — architectural audit + R6 gap analysis + dev environment)
Target: `docs/architecture/` (directory), `CLAUDE.md`
Status: **Applied 2026-06-24** (direction provided inline; no separate proposal phase)

---

## Summary

Round 7 had two structural impacts on the architecture layer:

1. **Directory creation (A3)** — `docs/architecture/` was created with five files extracted from
   `docs/technical-design.md §6–§16`. The extracted files are the authoritative specs;
   `technical-design.md` was reduced to a lean overview with navigation stubs linking into them.

2. **R7-specific additions** — several Round 7 decisions introduced new content directly into the
   architecture files rather than into `technical-design.md`. These are documented below alongside
   the extraction record.

Additionally, `CLAUDE.md` received a new "Development toolchain" section documenting the agreed
toolchain and platform decisions from Section E of `r7-review.md`.

Items marked **⚠️ Verify** require code-level confirmation when the relevant phase is built.

---

## Change index

| # | File | Type | Status |
|---|---|---|---|
| 1 | `docs/architecture/` (directory) | Created — 5-file extraction from `technical-design.md §6–§16` | ✅ Applied |
| 2 | `index.md` | New — navigation index + R6 schema rename reference | ✅ Applied |
| 3 | `core-domain.md` | New — §1 entity model, §2 module layout + recommended stack, §3 service responsibilities | ✅ Applied — ⚠️ Verify cross-links |
| 4 | `containers-and-budgets.md` | New — workspace structure, file classification, all 28 CSV/MD specs (§8.1–§8.28) | ✅ Applied — ⚠️ Verify specs at Phase 2 |
| 5 | `rulesets-and-taxes.md` | New — validation rules + UI requirements; delete-on-reference reassign policy added (B1) | ✅ Applied — ⚠️ Verify when write flows built (Phase 6) |
| 6 | `data-pipelines.md` | New — read/write/repair flows, developer scripts, ingestion pipeline diagrams (A4) | ✅ Applied — ⚠️ Verify write flow note (see below) |
| 7 | `core-domain.md §2` | R7 addition — recommended stack: macOS 15, Xcode 16, Swift 6 (E2) | ✅ Applied |
| 8 | `core-domain.md §2` | R7 addition — Business module note: no standalone BusinessEngine (B3) | ✅ Applied |
| 9 | `core-domain.md §3` | R7 addition — ICloudContainerService sync-first write gate (C1) | ✅ Applied — ⚠️ Verify when ICloudContainerService built (Phase 1) |
| 10 | `core-domain.md §3` | R7 addition — OverviewEngine typed "data not available" stub contract | ✅ Applied — ⚠️ Verify at Phase 3 |
| 11 | `CLAUDE.md` | R7 addition — Development toolchain section (E1–E4) | ✅ Applied |
| 12 | Changelog | R7 entry in `technical-design.md` covers extraction; this file documents architecture-side changes | ✅ Applied |

---

## Detailed changes

### Directory creation (`docs/architecture/`)

Five files created as part of the architecture split (A3). Content was moved from
`docs/technical-design.md §6–§16`; those sections were replaced with 2-line navigation stubs.
The extracted files are **authoritative** — `technical-design.md` stubs are navigation aids only.
When a spec detail changes, update the relevant `docs/architecture/` file directly.

| File | Source sections | Contents |
|---|---|---|
| `index.md` | New | Navigation index linking all four spec files; R6 schema rename table |
| `core-domain.md` | §10–§12 | Internal data model (§1), module layout (§2), service responsibilities (§3) |
| `containers-and-budgets.md` | §6–§8 | Workspace folder structure (§1), manifest format (§2), all 28 CSV/MD file specs (§3) |
| `rulesets-and-taxes.md` | §15–§16 | Validation rules — file, cross-file, domain, repairable (§1); UI requirements per module (§2) |
| `data-pipelines.md` | §13–§14 | Read/write/repair flows (§1), developer scripts (§2), ingestion pipeline diagrams (§3) |

- ⚠️ **Verify (ongoing)**: whenever a spec detail changes, update the relevant `docs/architecture/` file — do not add detail back to `technical-design.md`.

---

### `index.md` — new

Content:
- Navigation table linking to all four spec files with one-line descriptions.
- Quick-navigation table: maps common questions ("Column names for a specific CSV file", "What AccountEngine is responsible for", etc.) to the right file and section.
- R6 schema rename reference table (old name → new name for all six renames from Round 6).

No R7-specific content additions beyond the structure above.

---

### `core-domain.md` — new with R7 additions

Extracted from `technical-design.md §10–§12`; three R7-specific additions applied:

**§1 — Internal data model (entities)**
- Entity list extracted from Tech Design §10.
- Canonical names applied: `Transaction` (not `PersonalTransaction`/`BusinessTransaction`), `Category`, `Budget`, account-group object (`entity` → `AccountGroup`). FIX references `[FIX-M6]` and `[FIX-C6]` noted for pre-Phase 3 resolution.
- **R7 addition (B3)**: clarification note — Business is `group_type = business` under Accounts; no standalone BusinessEngine; all business P&L lives in `AccountEngine`. `[FIX-C3]` and `[FIX-S2]` retired.

**§2 — Application architecture / module layout**
- Module layout extracted from Tech Design §11.
- **R7 addition (E2)**: "Recommended stack" subsection — macOS 15 (Sequoia) minimum deployment target (update to latest stable at Phase 1 build start), Xcode 16 (update to latest stable at build start), Swift 6, SwiftUI, Swift Charts, Observation (`@Observable`, requires macOS 14+; macOS 15 satisfies), Foundation FileManager, NSFileCoordinator, Uniform Type Identifiers.
- **R7 addition (B3)**: Business module note added after module layout tree — no `Domain/Business/` subfolder; business P&L in `AccountEngine`.

**§3 — Service responsibilities**
- Service descriptions extracted from Tech Design §12.
- **R7 addition (C1)**: ICloudContainerService expanded with sync-first write gate detail:
  - Exposes per-file sync state (`available`, `downloading`, `uploading`, `conflict`, `error`).
  - Write layer queries sync state before applying any write plan.
  - Write actions disabled while workspace `syncState` is `syncing` or targeted file is `downloading`.
  - On launch: write actions disabled until all monitored files are `available`.
  - On write attempt: `WritePlanBuilder` queries `ICloudContainerService.syncState(for:)` before building plan; if not `available`, write deferred with non-blocking inline banner.
  - On iCloud push: affected file marked `downloading`; write actions targeting it disabled until re-index completes.
  - NSFileCoordinator (via `FileCoordinatorService`) serializes all concurrent reads/writes at OS level.
- **R7 addition (OverviewEngine stub contract)**: `OverviewEngine` returns a typed "data not available" state when downstream engines are stubs in Phase 3 — not nil, not empty zero values — so Overview dashboard renders a distinct empty card.
- ⚠️ **Verify (Phase 1)**: `ICloudContainerService.syncState(for:)` exposed and `WritePlanBuilder` queries it on every write attempt.
- ⚠️ **Verify (Phase 3)**: `OverviewEngine` typed empty state implemented; Overview dashboard renders the distinct empty card.

---

### `containers-and-budgets.md` — new

Extracted from `technical-design.md §6–§8`. Contains all 28 CSV/MD file specs (§3.1–§3.28).
No R7-specific spec content changes — all specs are as defined in Round 6.

- ⚠️ **Verify (Phase 2)**: all 28 specs reviewed and confirmed complete before `CSVSchemaRegistry` is built. See `docs/project-management.md [FIX-R6-M1]–[FIX-R6-M4]` for schema migration tasks needed before parsing is built.

---

### `rulesets-and-taxes.md` — new with R7 addition

Extracted from `technical-design.md §15–§16`.

**§1 — Validation rules (cross-file)**
- **R7 addition (B1)**: delete-on-reference rule added to cross-file validation:
  - **Default: reassign** (locked Round 7).
  - Before deleting a row, resolve inbound references grouped by collection with counts.
  - Write preview lists referencing rows and presents a reassignment picker per referencing collection. Nullable references may be left unlinked.
  - Delete and all reassignments written atomically — no partial state. User can cancel the entire operation.
  - App never silently drops referencing rows; never blocks a confirmed delete with a valid reassignment.
  - References `docs/product-requirements.md §12` for the full requirement.
- ⚠️ **Verify (Phase 6)**: `WritePlanBuilder` implements atomic write; reassignment preview panel surfaces correct referencing rows for each entity type.

---

### `data-pipelines.md` — new with pipeline diagrams

Extracted from `technical-design.md §13–§14`.

**§3 — Ingestion pipeline diagrams (A4)**
- New in Round 7. Read gap A4 in `r7-review.md` identified that pipeline flows existed as text but lacked visual diagrams to support implementation. Diagrams added for:
  - Read pipeline (workspace scan → classify → parse → validate → project → render).
  - Write pipeline (UI action → write plan → sync check → preview → backup → atomic write → re-index).
  - Repair pipeline (validation issue → repair preview → confirm → backup → apply → re-validate).
  - Ingestion pipeline (external CSV → file picker → column mapper → normalizer → validate → preview → write).

**⚠️ Write flow note — stale reference (requires follow-up)**
`data-pipelines.md §1` (structured write flow section) still contains the pre-R7 language:
> "Delete-on-reference behavior: block vs. cascade-warn vs. reassign is an **open decision** tracked in project-management.md (Phase 6 [DECIDE]). Decide before implementing Phase 6 delete flows. The default will be written into rulesets-and-taxes.md §1 once resolved."

This is now stale: the decision was locked Round 7 as reassign, and `rulesets-and-taxes.md §1` has been updated. The `data-pipelines.md §1` note should be updated to reference the locked decision before Phase 6 write flows are built.
- ⚠️ **Verify (before Phase 6)**: update `data-pipelines.md §1` write flow section to remove the "open decision" language and reference `rulesets-and-taxes.md §1` for the locked reassign policy.

---

### `CLAUDE.md` — development toolchain section (E1–E4)

New section "Development toolchain" added between "V1 scope boundaries" and "Spec Kit workflow".

Contents:
- **Primary AI dev assistant**: Claude Code (this file). Build/test commands and session-start hook added in Phase 1.
- **Primary IDE**: Google Antigravity 2.0 / Antigravity IDE. Xcode remains required as the macOS build toolchain (compile, sign, archive); Antigravity is the day-to-day development and code editing environment. Not interchangeable — Xcode is required.
- **Design-to-code bridge**: figma-cli (`https://github.com/silships/figma-cli`) — local CLI communicating with Figma Desktop via CDP (no API key, no rate limits). Not an MCP server. Yolo mode default. Design tokens (DTCG/W3C) exported to `docs/_design/tokens/`; icons/SVGs to `docs/_design/icons/`. Component specs generated on demand, not committed. Claude Code handles installation in Phase 1.
- **Secondary IDEs (later phases)**: VS Code and Kiro as candidates.
- **Platform requirements**: macOS 15 (Sequoia), Xcode 16, Swift 6, GitHub Actions CI/CD.

Source: E1 (figma-cli), E2 (macOS/Xcode/Swift), E3 (CI/CD), E4 (Figma handoff policy).

---

## Items explicitly NOT changed

- **`containers-and-budgets.md` spec content** — R6 specs extracted as-is; no schema changes in R7.
- **`rulesets-and-taxes.md §2` UI requirements** — extracted as-is; no UI requirement changes in R7.
- **`technical-design.md §1–§5`** — purpose, design goals, system overview, IA, sync states unchanged and remain in the overview file (not extracted).
- **`technical-design.md §9` manifest format** — abbreviated inline stub kept in `technical-design.md` (short and frequently referenced); also linked from `containers-and-budgets.md §2`.
- **`technical-design.md §21` locked decisions** — remain in the overview file as the single locked-decision record; not duplicated in architecture files.

---

## Changelog stub (appended to architecture files)

Each architecture file carries an extraction provenance note at the top. The authoritative R7
change record for the architecture split is in `docs/technical-design.md` changelog:

```
### Round 7 — 2026-06-24
Source: docs/_refinement/r7-review.md (MVP prep — architectural audit + R6 gap analysis);
update plan docs/_refinement/r7-update-architecture.md

- docs/architecture/ created: index.md, core-domain.md, containers-and-budgets.md,
  rulesets-and-taxes.md, data-pipelines.md — detailed spec content extracted from §6–§16
- core-domain.md §2: recommended stack added (macOS 15, Xcode 16, Swift 6); Business module note
- core-domain.md §3: ICloudContainerService sync-first write gate detail added (C1);
  OverviewEngine stub contract added
- rulesets-and-taxes.md §1: delete-on-reference locked as reassign (B1)
- data-pipelines.md §3: ingestion pipeline diagrams added (A4) — new in R7
- CLAUDE.md: Development toolchain section added (E1–E4)
- data-pipelines.md §1 write flow note: stale "open decision" language for delete-on-reference
  not yet updated — update before Phase 6 [⚠️ pending]
```
