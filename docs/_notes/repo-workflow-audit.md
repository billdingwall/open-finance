# Repository Workflow Audit

**Date**: 2026-06-11
**Scope**: Repository structure, document workflows, git conventions, and automation — audited against `docs/_notes/workflow-overview.md`.
**Method**: Full repo scan post workflow-cleanup (commit `bd7edb3`). Findings ordered by severity; each has a concrete recommendation.

---

## What is working well

- **Naming and structure are now consistent.** All docs follow kebab-case, the `_refinement/` / `_notes/` split matches the defined workflow, and a repo-wide scan finds zero stale path references. Git history preserved all 14 renames as renames.
- **Update plans are traceable.** Both `update-*-r1.md` files carry `Source` / `Target` / `Status: Applied` headers — the synthesis step of the refinement loop leaves an auditable trail.
- **Spec Kit is fully wired.** Templates, git automation, quality gates, and the constitution check are all in place, with `specs/001-prototype-prd-alignment/` as a complete exemplar run.
- **Repo hygiene basics are covered.** `.DS_Store` is ignored, the working tree is clean, and core docs carry changelogs.

---

## Findings and recommendations

### High priority

**H1 — No automation prevents reference drift from recurring**
The cleanup just completed fixed ~40 stale references by hand. Nothing stops the same drift next time a file is renamed: there is no CI (no `.github/`), no link checker, and no naming-convention check.
*Recommendation*: Add a lightweight docs CI job (GitHub Actions) that runs on PRs:
1. a relative-link checker over `*.md` (e.g. `lychee --offline` or `markdown-link-check`);
2. a kebab-case filename check for `docs/**`;
3. optionally, a grep deny-list for retired names (`PRD.md`, `_reviews/`, `roadmap-v1`, `design/prototype`).
A `Scripts/validate-docs.sh` that does the same locally would cover pre-push.

**H2 — `project-management.md` items have no status tracking**
The `[FIX]` / `[DECIDE]` items are prose paragraphs with no checkbox, status, owner, or resolution date. There is no way to mark an item done short of deleting it, which destroys the audit trail. (Contrast with the roadmap, which uses `- [x]` checkboxes with completion dates.)
*Recommendation*: Add a status line to each item (`Status: Open | Resolved YYYY-MM-DD — outcome`) or convert items to checkbox form, and append a short "Resolved" log section. Several items may already be resolvable from the 2026-06-10 locked decisions — sweep them first.

**H3 — `.specify/feature.json` points at a completed feature**
The active-feature pointer still references `specs/001-prototype-prd-alignment`, which is done and merged. The next `/speckit-*` invocation that reads the pointer could write artifacts into the completed feature's directory.
*Recommendation*: Clear or null the pointer between features, and make resetting it part of the feature-completion routine (could be added to the `/speckit-git-commit` flow or a small closeout checklist).

### Medium priority

**M1 — Rounds 2 and 3 bypassed the refinement loop**
`product-requirements.md` logs a Round 2 changelog entry (2026-06-09) and `technical-design.md` logs Rounds 2 and 3 (2026-06-10), but `docs/_refinement/` contains only Round 1 artifacts — no `review-r2.md`, `review-r3.md`, or matching update plans exist. The documented loop (review → update plan → apply) was only followed for Round 1.
*Recommendation*: Decide whether small rounds may skip the formal artifacts. If yes, document the threshold in `workflow-overview.md` (e.g. "single-doc changes may be applied directly with a changelog entry"). If no, backfill stub records for Rounds 2–3 so the changelog and `_refinement/` stay in one-to-one correspondence.

**M2 — `product-roadmap.md` has no Changelog section**
The refinement loop says changes cascade to the roadmap "each with a Changelog entry," and the PRD and technical design both have one. The roadmap does not, so its revision history is invisible.
*Recommendation*: Add a `## Changelog` section to the roadmap and backfill from git history (Rounds 1–3 touched it).

**M3 — No template or header convention for review files**
`review-r1.md` opens with raw content — no date, round number, participants, prototype version, or status. The update plans have a header convention; reviews do not, and `.specify/templates/` only covers Spec Kit artifacts.
*Recommendation*: Add a minimal header block to future reviews (Round, Date, Prototype state reviewed, Sources/assets) — either as a note in `workflow-overview.md` or a `docs/_refinement/template-review.md`.

**M4 — Branch namespace collision and unpruned branches**
The `NNN-feature-name` convention is reserved for Spec Kit features, yet branch `001-update-docs` (a docs change) reused `001`, colliding with feature `001-prototype-prd-alignment`. Non-feature branches have no convention (`repo-workflows-update`, `claude/requirements-workflow-cleanup-vkmc8v`). Merged branches remain locally and on the remote.
*Recommendation*: Reserve `NNN-` strictly for spec features; use a prefix for everything else (`docs/<topic>`, `chore/<topic>`). Delete merged branches (`001-update-docs`, `claude/requirements-workflow-cleanup-vkmc8v`) locally and on origin. Note the convention in `workflow-overview.md`.

**M5 — Superseded documents live alongside active notes**
`docs/_notes/` mixes active reference material with documents that are explicitly retired: `consistency-audit.md` and `open-decisions.md` are superseded by `project-management.md` ("Replaces both source documents for day-to-day use"), and `workflow-overview-v1.md` is the archived pre-cleanup proposal. `open-decisions.md` also predates the decision lock, so its "unresolved" framing is misleading.
*Recommendation*: Create `docs/_notes/_archive/` and move all three there (or delete them — git history preserves the content). Add a superseded banner at the top of each pointing to its replacement.

### Low priority

**L1 — `project-management.md` title mismatch**
The file is still titled `# Pre-Build Items` from its old filename. Rename the H1 to match (`# Project Management` or `# Pre-Build Project Management`) and keep "pre-build items" in the description.

**L2 — `prototype/` has no README**
There is no top-level note on how to open the prototype (file:// in a browser, no server) or which review round it reflects. That information exists only inside `specs/001-prototype-prd-alignment/quickstart.md`, buried in a feature directory.
*Recommendation*: Add a short `prototype/README.md` covering how to run it, what round it is current to, and the demo affordances (sync-state cycling, onboarding flow, indexing view in Settings → Workspace).

**L3 — `docs/_design/` has no round or versioning convention**
The folder holds one SVG. The refinement loop expects design assets to update every round, but nothing ties an asset to the round that produced it.
*Recommendation*: Adopt a light convention before assets accumulate — either round suffixes (`accounts-overview-r2.svg`) or per-round subfolders, mirroring `_refinement/`.

**L4 — Workflow documentation is described in three places**
README.md, CLAUDE.md, and `workflow-overview.md` each describe the repo structure and review workflow. They are consistent today (post-cleanup) but are three copies that can drift independently — this audit exists because exactly that happened.
*Recommendation*: Treat `workflow-overview.md` as the single source of truth; trim README and CLAUDE.md to summaries plus a pointer. The H1 CI deny-list also reduces the cost of future drift.

---

## Suggested sequencing

| Order | Items | Rationale |
|---|---|---|
| 1 | H3, L1, M5 | Five-minute fixes; remove stale state before it misleads anyone. |
| 2 | H2, M2 | Establish status tracking and roadmap changelog before pre-build work starts consuming `project-management.md`. |
| 3 | H1 | Add docs CI — the highest-leverage guard before the team and doc volume grow. |
| 4 | M1, M3, M4 | Process decisions to encode in `workflow-overview.md`; fold into the next refinement round. |
| 5 | L2, L3, L4 | Opportunistic; bundle with the next prototype or design update. |
