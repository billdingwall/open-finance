# Repository Workflow Overview

> Updated: 2026-06-11. Reflects the repository after the workflow cleanup on branch `repo-workflows-update`. The pre-cleanup proposal this replaces is archived as `workflow-overview-v1.md`.

---

## Two Distinct Workflows

The repository runs two distinct but connected workflows:

1. A **project-level documentation workflow** for maintaining the living design documents that define the entire product.
2. A **feature-level specification workflow** (Spec Kit) for defining, implementing, and maintaining individual features.

The project-level docs live on `main` and evolve through prototype review rounds. Feature work happens on numbered branches and produces self-contained artifact sets under `specs/`.

---

## 1. Repository Structure

```
open-finance/
├── docs/
│   ├── product-requirements.md    # What & why — modules, user scenarios, data model, IA
│   ├── technical-design.md        # How & where — architecture, CSV specs, service design
│   ├── product-roadmap.md         # When — phased plan with milestone gates
│   ├── project-management.md      # Tasks — remaining work before the Phase 1 build
│   ├── _refinement/               # Review rounds and doc update plans
│   │   ├── r{n}-review.md         # Raw feedback (or user-direction note) per round
│   │   └── r{n}-update-{doc}.md   # Formatted update plan per target doc per round
│   ├── _design/                   # Design mocks, icons, images, design system
│   └── _notes/                    # Loose notes and domain research (kebab-case names)
├── prototype/                     # Static HTML/CSS/JS prototype for design review
├── specs/                         # Feature-level Spec Kit artifacts (NNN-feature-name)
├── .specify/                      # Spec Kit workflow engine, templates, constitution
├── .claude/skills/                # The 14 Spec Kit skills as Claude-executable files
├── CLAUDE.md                      # AI assistant context — bridge between both workflows
└── README.md
```

### Document roles

| Document | Role |
|---|---|
| `docs/product-requirements.md` | What & why: primary product direction — modules, user scenarios, data model, IA. Changelog at bottom. |
| `docs/technical-design.md` | How & where: architecture decisions, UX decisions, interface design, all 24 CSV specs, service responsibilities, validation rules. Locked-decision record in §21. |
| `docs/product-roadmap.md` | When: phased plan with Product/Design/Dev tasks and milestone gates. |
| `docs/project-management.md` | Tasks: consolidated decisions and doc fixes remaining before the Phase 1 build. |
| `docs/_refinement/r{n}-review.md` | Raw feedback from the team (or a short user-direction note) with links to design assets and notes. |
| `docs/_refinement/r{n}-update-{doc}.md` | Formatted doc update plan synthesized from a round (e.g. `r4-update-product-requirements.md`, `r4-update-technical-design.md`). |
| `docs/_design/*` | Design mocks, icons, images, design system. |
| `docs/_notes/*` | Loose notes and domain research for team reference (e.g. `account-types.md`, `deduction-types.md`). |
| `prototype/*` | Static prototype used to review and refine the app experience before implementing changes. |
| `.specify/memory/constitution.md` | Non-negotiable governing principles informed by the project-level docs. All spec documents must conform to it. |

### Naming conventions

- All doc and note filenames are **kebab-case** (`account-types.md`, not `Account types.md`).
- Review rounds: `r{n}-review.md` (round-first, so all files for a round group together in the listing).
- Update plans: `r{n}-update-{target-doc}.md` — one per affected document per round.
- **Round numbers are global**: one round = one revision event (prototype review *or* user
  direction), numbered sequentially by date and shared across all docs and the changelog entries.
  A doc that was not touched in a given round simply has no `r{n}-update-` file and no changelog
  entry for it. This keeps the changelogs and the `_refinement/` files lined up.
- Feature directories and branches: `NNN-feature-name` with sequential numbering.

---

## 2. Project-Level Requirements Workflow

This governs the core design documents that define the entire product. They can be influenced from three perspectives — product, design, and development — each feeding the same refinement loop.

### Core documentation flow

```
User needs
↓
docs/product-requirements.md
↓
docs/technical-design.md
↓
docs/product-roadmap.md
↓
docs/_design/* → prototype/*
↓
specs/*
↓
OpenFinance app
```

### Product refinement loop

```
Prototype review & UX design
↓
docs/_refinement/r{n}-review.md
↓
docs/_refinement/r{n}-update-{doc}.md
↓
docs/product-requirements.md      (+ Changelog entry)
↓
docs/technical-design.md          (+ Changelog entry)
↓
docs/product-roadmap.md
↓
docs/_design/* → prototype/*
↓
Start next round of prototype review
```

Step by step:

1. **Review** — add `docs/_refinement/r{n}-review.md` with UX and functionality notes (for a prototype round) or a short direction note (for a user-direction round). `{n}` is the next global round number.
2. **Domain research** — add named kebab-case research docs to `docs/_notes/` as questions arise.
3. **Update plan** — synthesize review and research into `docs/_refinement/r{n}-update-{doc}.md` per affected document, with a section-by-section change list. Mark the plan `Applied` with a date once executed.
4. **Apply updates** — edit `docs/product-requirements.md` first, then cascade to `docs/technical-design.md` and `docs/product-roadmap.md`, each with its own Changelog entry.
5. **Constitution check** — if principles changed, amend `.specify/memory/constitution.md` with a version bump and Sync Impact Report update.
6. **Design & prototype** — update `docs/_design/` assets and `prototype/` to reflect the changes, then start the next review round.
7. **Commit** — all affected docs together in a single commit.

### Project-level → feature-level handoff

```
product requirements → constitution.md
↓
technical design → constitution.md
↓
roadmap → phases of feature development
↓
specs → feature requirements
↓
feature delivery ← prototype ← design
↓
OpenFinance app
```

---

## 3. Feature-Level Specification Workflow (Spec Kit)

This governs how individual features move from idea to implementation-ready tasks. The workflow is linear with quality gates at each step.

### Command sequence

```
/speckit-specify    Natural language description → spec.md
       ↓
/speckit-clarify    Resolve underspecified areas (max 3 rounds)
       ↓
/speckit-plan       Generate plan.md + research.md + data-model.md + contracts/
       ↓
/speckit-tasks      Produce dependency-ordered tasks.md
       ↓
/speckit-implement  Execute tasks from tasks.md
```

Optional supporting commands:
- `/speckit-checklist` — generate a custom checklist for the feature
- `/speckit-analyze` — cross-artifact consistency and quality audit
- `/speckit-taskstoissues` — push tasks to GitHub Issues

Git automation commands (`/speckit-git-feature`, `/speckit-git-commit`, `/speckit-git-validate`, `/speckit-git-remote`, `/speckit-git-initialize`) handle branch creation with sequential `NNN-feature-name` numbering and auto-commits after each phase.

### Artifact set (full run)

The one completed feature — `specs/001-prototype-prd-alignment/` — shows what a full run produces:

```
specs/001-prototype-prd-alignment/
  spec.md          ← what & why (user stories, requirements, success criteria)
  research.md      ← unknowns resolved, decisions documented
  data-model.md    ← entities, fields, validation rules
  plan.md          ← phases, constitution check, technical context
  contracts/
    nav-structure.md
  quickstart.md
  tasks.md         ← dependency-ordered, parallelism-marked, story-mapped tasks
  checklists/
    requirements.md
```

### Quality gates

| Gate | Description |
|---|---|
| Spec validation | No implementation details; requirements testable and unambiguous; max 3 `[NEEDS CLARIFICATION]` markers |
| Clarification rounds | Max 3 rounds before documenting remaining issues |
| Constitution Check | Runs before Phase 0 research and again after Phase 1 design |
| Violation justification | Any constitution violation must be documented in the Complexity Tracking table with explicit rationale |

### Workflow engine (`.specify/`)

| Path | Purpose |
|---|---|
| `templates/` | Canonical templates for spec, plan, tasks, constitution, and checklist. Claude fills these in during each command. |
| `memory/constitution.md` | The governance document. Every plan runs a Constitution Check against it. |
| `extensions/git/` | Git automation: branch creation scripts, auto-commit hooks, naming conventions. |
| `extensions.yml` | Lifecycle hooks wiring git operations to each Spec Kit command phase. |
| `feature.json` | Pointer to the currently active feature directory. |
| `init-options.json` | Configuration: Claude integration, sequential branch numbering, `CLAUDE.md` as context file. |
| `workflows/speckit/workflow.yml` | Full SDD cycle definition (specify → plan → tasks → implement with review gates). |
| `integrations/claude.manifest.json` | Manifest of all 14 installed Claude skills with versions and hashes. |

The 14 skills themselves live in `.claude/skills/` as Claude-executable skill files. Each reads the templates, runs quality checks, and writes artifacts to the active feature directory.

---

## 4. The Dependency Chain

```
.specify/memory/constitution.md   governs everything
       ↓
docs/product-requirements.md      defines what gets built
       ↓
docs/technical-design.md          defines how it gets built
       ↓
docs/product-roadmap.md           sequences when it gets built
       ↓
specs/NNN-feature-name/           operationalizes individual features
```

A feature branch contains only the Spec Kit artifacts for that feature. The project-level docs live on the main branch and are updated separately via the refinement loop.

`CLAUDE.md` is the bridge between the two workflows. It tells Claude which documents to read before making changes, what the architecture constraints are, what is in and out of scope for V1, and the step-by-step doc update workflow.

---

## 5. Current Status

- **Phase**: pre-build. No Swift source exists; the Xcode project is created in Phase 1 of the roadmap.
- **Refinement rounds**: Round 1 (2026-06-08, prototype review) — applied. Round 2 (2026-06-09,
  user direction: multi-cloud + file formats) — applied. Round 3 (2026-06-10, user direction:
  sidebar refinement + Phase 1 decision lock) — applied. Rounds 2–3 were originally applied
  directly to the docs and were documented retroactively in `_refinement/` on 2026-06-12 so the
  changelogs and refinement files line up. Round 4 (2026-06-12, second prototype review:
  screen consolidation) — applied to the PRD, technical design, roadmap, and prototype on
  2026-06-12.
- **Architectural decisions**: all Phase 1 decisions locked 2026-06-10; record in `docs/technical-design.md §21`. Remaining pre-build items tracked in `docs/project-management.md`.
- **Features completed**: `001-prototype-prd-alignment` (prototype brought into alignment with the post-Round-1 PRD).
