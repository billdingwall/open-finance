# Architectural Audit: Open Finance Workspace

**Date:** 2026-06-23
**Scope:** `docs/product-requirements.md`, `docs/technical-design.md`, `docs/product-roadmap.md`, `docs/project-management.md`, `CLAUDE.md`, and `prototype/`

---

## 1. What's Working

- **Clear Layered Architecture:** The five-layer architecture (Storage, Indexing, Parsing, Domain, Projection) enforces a strict unidirectional dependency graph. This creates a highly testable and decoupled system where UI projections are deterministically generated from source files.
- **File-First Source of Truth:** Relying on standard CSV and Markdown files stored in iCloud provides user transparency and portability. Avoiding a proprietary database lock-in is a strong differentiator for a personal finance app.
- **Well-Defined Validation:** The `ValidationEngine` explicitly tracks the provenance of data issues directly to the source file and row, allowing for guided user repair flows rather than failing silently.
- **Strong Master Registry:** Treating `Accounts/accounts.csv` as the unified master account registry prevents duplicate or orphaned accounts across the Budget, Tax, and Investment domains.
- **Solid Prototype Foundation:** The static HTML/JS prototype correctly demonstrates the data flow, using `store.js` with `localStorage` to simulate file changes applied on top of the immutable seed data in `data.js`.

## 2. What's Not Working

- **Missing Write/Edit Operations:** Both the PRD and the prototype outline creating and viewing data, but standard edit/delete flows are completely missing from the prototype. The prototype inspector is read-only. This is a massive functional gap for a data-entry app.
- **Incomplete Deletion Semantics:** The documentation (`docs/project-management.md`) explicitly lists "Default delete behavior when an object is referenced" as an open decision. Deleting an account or category that has hundreds of linked transactions needs defined cascade rules (block, cascade-warn, or reassign) before Phase 6.
- **Ambiguity in Cross-Entity Sync:** Business records and Tax adjustments are heavily coupled. Tax features are relying on business records (`business-expense`), but the UI structure still considers Business a "theme" of Accounts rather than a fully independent domain, complicating the UI navigation structure.
- **Prototype State Drift:** The prototype currently implements "create" flows but lacks the full scope of user write preview and auto-repair behaviors requested in the Technical Design.

## 3. What Could Be Improved

- **File Concurrency Handling:** The architecture assumes iCloud handles synchronization, but the technical design lacks deep coverage of atomic file conflict resolution. While it mentions conflict detection (`Conflict detected` UI state), it does not detail how the app resolves concurrent writes if two devices edit `transactions.csv` while offline.
- **Data Initialization (Bootstrap):** Bootstrapping a workspace involves creating ~20 files. The onboarding flow requires heavy templating. Providing clear, pre-filled "demo" data sets could improve the first-time user experience.
- **File Watching at Scale:** Relying on `FileWatcherService` to re-index potentially thousands of rows of transactions across dozens of CSVs could become a performance bottleneck on low-power Macs, especially if UI main-thread blocking isn't heavily guarded.
- **Markdown Handling:** The PRD waffles on the complexity of the Markdown viewer (V1 vs V2). Clarifying exactly which subset of Markdown (headers, tables, links) is supported in the right detail pane will prevent scope creep.

## 4. Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| **Technical:** iCloud sync latency and conflicts leading to data loss or duplicated rows. | High | High | Implement strict file hashing, atomic writes to temp files before rename, and robust conflict UI flows (letting the user pick the winner). |
| **Technical:** Re-indexing performance degradation over multiple years of transaction data. | Medium | High | Implement incremental parsing, projection caching keyed by file hash, and offload all parsing to background threads. |
| **Architectural:** `AccountEngine` becomes a monolithic dependency bottleneck because every other engine requires it. | Medium | Medium | Ensure `AccountEngine` strictly provides read-only projection interfaces and does not absorb domain logic from Taxes or Investments. |
| **Scope/Complexity:** Tax prep logic and tax-lot tracking expanding beyond basic reporting into full tax calculation. | High | Low | Strictly enforce the "No tax filing engine in v1" rule from the PRD. Keep calculations strictly informational. |
| **Build:** Implementation of UI "edit/delete" operations lagging due to undefined cascade rules. | High | Medium | Force a decision on the "delete-on-reference" behavior immediately before Phase 6 begins. |

## 5. Local Development Workflow

The local development loop strictly avoids Xcode to keep the toolchain lightweight and modular.

### Tools Overview
- **Antigravity IDE:** The primary coding environment for writing Swift source code, Markdown documentation, and executing scripts.
- **Claude Code:** The AI assistant used to execute the Spec Kit workflows (`/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement`), refactor code, and update project-level documentation based on refinement rounds.
- **Antigravity 2.0 app:** Used for compiling, running, and previewing the macOS application locally without needing the full Xcode GUI.
- **Jules:** Handles asynchronous background tasks, such as generating tests, running deep dependency audits, and executing the project-wide linting and pre-commit checks.

### Environment Setup
1. **Repository & Dependencies:** Clone the repository. Ensure Swift CLI tools are available.
2. **Workspace Setup:** Create a local mock iCloud folder (e.g., `~/Finance-Dev/`) to act as the development source of truth.
3. **Seeding Data:** Run `Scripts/fixture-generate.swift` to populate the mock folder with a realistic dataset (12 months of transactions, accounts, etc.).

### Day-to-Day Development Loop
1. **Spec & Plan (Claude Code):** When starting a new feature, use Claude Code to run `/speckit-specify` and `/speckit-tasks`.
2. **Code (Antigravity IDE):** Write the necessary Swift logic or update the UI components in Antigravity IDE based on the generated tasks.
3. **Build & Preview (Antigravity 2.0):** Use the Antigravity 2.0 app to build and launch the Open Finance app locally, pointing it to the mock `~/Finance-Dev/` folder.
4. **Test & Audit (Jules):** Offload test generation and architectural validation checks to Jules in the background.
5. **Review (Claude Code):** Use Claude Code to ensure the implementation adheres to the `constitution.md` principles and update the PRD/Roadmap if necessary.
6. **Commit:** Finalize the feature branch and submit for review.