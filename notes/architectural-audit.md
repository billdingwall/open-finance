# Architectural Audit: Personal Finance Workspace

**Date:** 2026-06-15
**Phase:** Pre-Build (Phase 1)
**Scope:** Current architecture, requirements docs, and prototype

This document provides a deep architectural analysis of the `open-finance` project before the build phase begins. It evaluates the current approach, calls out clear problems, highlights areas for improvement, assesses risks, and documents the local development workflow.

---

## 1. What's Working

The project has established a strong foundation with several commendable architectural decisions and practices:

*   **File-First "Source of Truth" Architecture:** Using plain CSV and Markdown files in iCloud Drive as the system of record is a brilliant move for user ownership and durability. It avoids proprietary database lock-in and aligns well with macOS user expectations (Finder integration).
*   **Clear 5-Layer Separation of Concerns:** The planned architecture (Storage -> Indexing -> Parsing -> Domain -> Projection -> Presentation) is extremely well-defined. This strict layered dependency model will make unit testing much easier and prevents UI logic from bleeding into data parsing.
*   **Unified Account Registry:** The decision to use a master `Accounts/accounts.csv` with a unified transaction ledger (differentiating business vs. personal via `account_group_id`) simplifies cross-domain linking significantly and prevents fragmenting the user's financial picture.
*   **Thorough Documentation & Refinement Loop:** The process of using `docs/_refinement/` rounds to update the PRD and Technical Design based on Prototype feedback is rigorous. The decisions are traceable and explicit.
*   **High-Fidelity Interaction Prototype:** The Round 5 updates to the prototype (adding `localStorage` persistence, real CSV exports, and functioning forms) transformed it from a static mock into a truly evaluable interaction model. This is invaluable for catching UX issues before writing Swift.

---

## 2. What's Not Working

Several gaps and anti-patterns need immediate attention before full-scale Swift development begins:

*   **Missing Edit/Delete Workflows in the Prototype:** As noted in the Gap Analysis, the prototype only implemented "Create" flows. The app requires structured editing for transactions, goals, accounts, and deductions. Without these in the prototype, the "Safe Writes" (preview, backup, apply) requirement is untested in UX.
*   **Unresolved "Open Decisions":** The `docs/project-management.md` file lists 80 tasks, with numerous `[DECIDE]` items in the Write Flows (Phase 6). Specifically, the lack of a defined "Backup retention policy", "Export column inclusion", and "CSV import preview flow" will block core features.
*   **Disconnect on Data Validation:** The prototype currently uses static mock data for validation (cannot generate *new* validation issues upon edit). The actual Swift app will require a robust, dynamic `ValidationEngine`. There is a risk that the UX for resolving dynamic, multi-row validation errors is underspecified.
*   **Vague "Conflict Resolution" Strategy:** The technical design punts on iCloud conflict resolution (`CloudStorageProvider` relies on iCloud-specific resolution). File-based architectures are highly prone to sync conflicts. If two devices append to the unified ledger simultaneously, the app needs a clearer merge strategy than "let iCloud duplicate the file."
*   **Empty State Definitions:** The prototype and PRD lack defined empty states for crucial areas (no savings goals, no holdings, no transactions for a given month). The app will feel broken to a new user without guided empty states.

---

## 3. What Could Be Improved

These are areas that aren't broken but are suboptimal and could create friction at scale:

*   **State Hydration Scale:** The architecture plans to read, parse, and project *all* CSV files into an internal normalized read model on launch. While fine for v1, this will not scale. A user with 10 years of transactions and daily price ticks will experience slow cold starts. A local caching layer (e.g., SQLite projection cache) should be considered for V2 to prevent re-parsing unchanged files.
*   **Dependency on `.finance-meta/`:** Storing the manifest, schemas, and backups in a visible `.finance-meta` folder in iCloud exposes critical app infrastructure to user modification. If a user deletes the manifest, the app must gracefully rebuild it from scratch without crashing.
*   **Tax Year Transition:** The "explicit in-app 'Close Tax Year' action" is currently undefined in its actual effects (what files get moved where). This needs to be strictly defined to avoid data loss or double-counting in January.

---

## 4. Risk Assessment

### Technical Risks

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| **iCloud Sync Latency / Conflicts** | High | High | Implement robust `NSFileCoordinator` usage. Add a clear "Sync Conflict" UI state. Design a deterministic merge strategy for appended CSV rows. |
| **Parsing Performance (Large Datasets)** | Medium | Medium | Move all CSV/Markdown parsing and `ValidationEngine` checks off the main thread. Implement projection caching to skip re-parsing unchanged files based on hash. |
| **File Watcher Thrashing** | Medium | High | Debounce `FileWatcherService` events, especially during bulk CSV imports or when iCloud downloads a batch of updates. |

### Architectural Risks

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| **Tight Coupling to Master Ledger** | Medium | Low | Because all domains rely on the unified `transactions/YYYY-MM.csv`, a schema change here breaks the whole app. Mitigation: Strict, versioned schema definitions and migration scripts. |
| **Over-engineering the Read Model** | Low | Medium | Resist the urge to build a full in-memory ORM. The projection layer should remain functional and derived. |

### Scope and Complexity Risks

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| **Tax Module Complexity** | High | High | Tax codes change and edge cases are infinite. Mitigation: Strictly bound the v1 tax module to *estimation* and *adjustment tracking* only. Refuse feature creep for actual filing or complex depreciation schedules. |
| **Investment Transaction Tracking** | High | Medium | Folding investment trades into the unified ledger (Round 6 decision) makes the ledger schema complex. Mitigation: Ensure the multi-entry group validation is rock-solid before launching. |

### Build Risks

| Risk | Severity | Likelihood | Mitigation |
| :--- | :--- | :--- | :--- |
| **Test Data Availability** | High | High | Building the Swift UI without realistic data will lead to layout errors. Mitigation: Complete the `fixture-generate.swift` script immediately (Phase 7 task) to provide developers with realistic, multi-year datasets. |

---

## 5. Local Development Workflow

This application will be built without Xcode. The primary local development workflow utilizes a modern, AI-assisted toolchain.

### Toolchain

*   **Antigravity IDE:** The primary coding environment. Used for writing Swift code, managing the project structure, and running terminal commands.
*   **Claude Code:** The AI assistant integrated into the terminal/workflow. Used for generating boilerplate, refactoring complex domain logic, reviewing PRs, and navigating the codebase.
*   **Antigravity 2.0 app:** Used for compiling, running, and previewing the Swift/SwiftUI application locally on macOS. It bypasses the need for the heavy Xcode build system.
*   **Jules:** Used for asynchronous background tasks. Jules will handle deep architectural analysis, test suite generation, dependency audits, and large-scale refactoring passes.

### Getting the Project Running (From Scratch)

1.  **Clone the Repository:** Pull down the `open-finance` repo.
2.  **Generate Fixture Data:** Run the developer script (once built) to populate a local `.finance-workspace` directory with realistic mock CSV/Markdown files: `./scripts/fixture-generate.swift --output ~/.finance-workspace`
3.  **Launch IDE:** Open the project directory in Antigravity IDE.
4.  **Start Preview:** Launch the Antigravity 2.0 app and point it to the `FinanceWorkspaceApp` directory to begin live-previewing the SwiftUI views.

### Day-to-Day Development Loop

1.  **Spec Review:** Use `/speckit-specify` to define the feature branch based on `tasks.md`.
2.  **Code Generation (Claude Code):** Ask Claude Code to stub out the Swift structures based on the `docs/technical-design.md` schema definitions.
3.  **Iterative UI Build (Antigravity):** Write SwiftUI views in Antigravity IDE. Use the Antigravity 2.0 app to instantly preview layout changes.
4.  **Domain Logic (Claude Code / Jules):** For complex logic (e.g., `ValidationEngine` rules), ask Claude Code to write the implementation and unit tests. For sweeping changes across domains, delegate to Jules as a background task.
5.  **Test:** Run unit tests via the terminal in Antigravity IDE. (e.g., `swift test`).
6.  **Prototype Parity Check:** Compare the Antigravity 2.0 app preview against the HTML/JS prototype in `prototype/index.html` to ensure visual and interactive fidelity.

### Tool Selection Guide

*   **Need to write a new SwiftUI View?** Use Antigravity IDE + Antigravity 2.0 app for instant feedback.
*   **Need to understand how `AccountEngine` parses `accounts.csv`?** Ask Claude Code to explain the flow.
*   **Need to write a massive suite of edge-case tests for the `TaxEngine`?** Assign the task to Jules.
*   **Need to update the PRD based on new findings?** Edit manually in Antigravity IDE and let Claude Code review the consistency against the Technical Design.

### Environment & Dependencies

*   **Swift Toolchain:** Requires a standard macOS Swift toolchain installation (manageable via homebrew or official installer) to support the `swift build` and `swift test` commands used by the Antigravity tools.
*   **No Xcode:** Ensure no `.xcodeproj` or `.xcworkspace` files are relied upon. The project must build cleanly using `Package.swift` (SwiftPM) and the Antigravity pipeline.
*   **Test Data Directory:** Developers must configure their local environment to point the `Storage layer` to a local folder (e.g., `~/.finance-workspace-test`) instead of actual iCloud Drive during active development to prevent mutating real user data.
