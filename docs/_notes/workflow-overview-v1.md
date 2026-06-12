# Requirements & Definition Workflow Overview

> Created: 2026-06-10. Basis for proposed cleanup on branch `claude/requirements-workflow-cleanup-vkmc8v`.

---

## Two Distinct Workflows

There are two distinct but related workflows: a **project-level documentation workflow** for maintaining living design documents, and a **feature-level specification workflow** (Spec Kit) for defining, implementing and maintaining individual features.

---

## 1. Project-Level Requirements Workflow

This governs the core design documents that define the entire product. The can be influenced from three different perspectives, product, design and development. Each perspective has a requirements contribution workflow.

### The Documents and Their Roles

| Document                                | Role                                                                                                                                     |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/product-requirements.md`          | What & why: Primary product direction — modules, user scenarios, data model, IA.                                                         |
| `docs/technical-design.md`              | How & where: Architecture decisions, user experience decisions, interface design, CSV specs, service responsibilities, validation rules. |
| `docs/product-roadmap.md`               | When: Phased plan with Product/Design/Dev tasks and milestone gates.                                                                     |
| `docs/project-management.md`            | Tasks: Remaining work needed before the Phase 1 build begins.                                                                            |
| `docs/_refinement/review-r{n}.md`       | Raw feedback from the team with links to design assets and notes                                                                         |
| `docs/_refinement/update-{doc}-r{n}.md` | Formatted docs update plan based on review.                                                                                              |
| `docs/_design/*`                        | Design mocks, icons, images, design system.                                                                                              |
| `docs/_notes/*`                         | Loose notes for reference by team.                                                                                                       |
| `prototype/*`                           | Static prototype used to review and refine the app experience before implementing changes.                                               |
| `.specify/memory/constitution.md`       | Non-negotiable governing principles informed by project-level docs: All spec documents must conform to it.                               |

### Update workflows

#### Core project-level documentation

```

User needs

docs/product-requirements.md
↓
docs/technical-design.md
↓
docs/product-roadmap.md
↓
docs/_design  → prototype/*
↓
specs/*
↓
OpenFinance app

```

#### Product refinement loop

```
Prototype review & UX design
↓
docs/_refinement/review-r{n}.md
↓
docs/_refinement/update-{doc}-r{n}.md
↓
docs/product-requirements.md
↓
docs/technical-design.md
↓
docs/product-roadmap.md
↓
docs/_design  → prototype/*
↓
Start next round of prototype review
```

#### Project-level → Feature-level handoff

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
OpenFinance  app

```

---

## 2. Feature-Level Specification Workflow (Spec Kit)

This governs how individual features move from idea to implementation-ready tasks. The workflow is linear with quality gates at each step.

### Command Sequence

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
- `/speckit-checklist` — Generate a custom checklist for the feature
- `/speckit-analyze` — Cross-artifact consistency and quality audit
- `/speckit-taskstoissues` — Push tasks to GitHub Issues

### Artifact Set (Full Run)

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

### Quality Gates

| Gate | Description |
|---|---|
| Spec validation | No implementation details; requirements testable and unambiguous; max 3 `[NEEDS CLARIFICATION]` markers |
| Clarification rounds | Max 3 rounds before documenting remaining issues |
| Constitution Check | Runs before Phase 0 research and again after Phase 1 design |
| Violation justification | Any constitution violation must be documented in the Complexity Tracking table with explicit rationale |

---

## 3. Repository Structure — How It Supports These Workflows

### `.specify/`

The workflow engine.

| Path | Purpose |
|---|---|
| `templates/` | Canonical templates for spec, plan, tasks, constitution, and checklist. Claude fills these in during each command. |
| `memory/constitution.md` | The governance document. Every plan runs a Constitution Check against it. |
| `extensions/git/` | Git automation: branch creation scripts, auto-commit hooks, naming conventions. |
| `extensions.yml` | Lifecycle hooks wiring git operations to each Spec Kit command phase. |
| `feature.json` | Pointer to the currently active feature directory. |
| `init-options.json` | Configuration: Claude integration, sequential branch numbering, context file location. |
| `workflows/speckit/workflow.yml` | Full SDD cycle definition (specify → plan → tasks → implement with review gates). |
| `integrations/claude.manifest.json` | Manifest of all 14 installed Claude skills with version and hashes. |

### `.claude/skills/`

The 14 Spec Kit skills as Claude-executable skill files. Each skill reads the templates, runs quality checks, and writes artifacts to the active feature directory.

**Installed skills:**

| Skill | Purpose |
|---|---|
| `speckit-specify` | Create feature spec from natural language |
| `speckit-clarify` | Identify and resolve underspecified areas |
| `speckit-plan` | Generate implementation plan and design artifacts |
| `speckit-tasks` | Generate dependency-ordered task list |
| `speckit-implement` | Execute tasks from tasks.md |
| `speckit-checklist` | Generate custom feature checklist |
| `speckit-analyze` | Cross-artifact consistency audit |
| `speckit-constitution` | Create or update the project constitution |
| `speckit-taskstoissues` | Convert tasks to GitHub Issues |
| `speckit-git-feature` | Create feature branch (sequential or timestamp) |
| `speckit-git-commit` | Auto-commit after Spec Kit command |
| `speckit-git-initialize` | Initialize repo with initial commit |
| `speckit-git-validate` | Validate branch naming conventions |
| `speckit-git-remote` | Detect GitHub remote URL |

### `specs/`

Where feature work lives. Each feature gets a numbered directory (`NNN-feature-name`) containing all its artifacts. The number is assigned sequentially by the git branching script.

### `docs/`

Project-level source of truth. Not generated output — these are human-maintained (with Claude assistance) and updated through the review loop above.

### `CLAUDE.md`

The bridge between the two workflows. It tells Claude:
- Which documents to read before making changes
- What the architecture constraints are
- What is in and out of scope for V1
- The step-by-step doc update workflow

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

A feature branch contains only the Spec Kit artifacts for that feature. The project-level docs live on the main branch and are updated separately via the review loop.
