# Round 6 Gap Analysis

## Summary
The implementation of the Round 6 recommendations is largely complete and well-executed across the primary downstream documents (`technical-design.md`, `product-requirements.md`, and `product-roadmap.md`). The major structural changes—such as renaming core objects (`account-groups`, `assets`, `tax-adjustments`), introducing `Liability` and `Portfolio` as first-class objects, integrating multi-entry transactions with `group_id` / `group_role`, and moving investment trades into the unified ledger—have been consistently applied. However, a few specific items, primarily related to the "Architectural recommendations" section of `r6-review.md` and updates to `project-management.md`, were missed and require further attention.

## What Was Implemented ✅

*   **Naming Alignment & Resolution Plan**
    *   **Recommendation:** Rename `entities.csv` to `account-groups.csv` (`account_group_id`, `group_type`), `holdings.csv` to `assets.csv` (`asset_id`), and `deductions.csv` to `tax-adjustments.csv` (`tax_adjustment_id`, `adjustment_type`).
    *   **Where Addressed:** `technical-design.md` (Sections 4, 6, 8.8, 8.14, 8.23, 21), `product-requirements.md` (Sections 5, 8, Changelog), and `product-roadmap.md` (Phase 1, 2, Changelog).
    *   **Status:** Fully implemented.

*   **New Objects (Liability and Portfolio)**
    *   **Recommendation:** Add `liabilities.csv` for debt positions and `portfolios.csv` as the parent container for investment sleeves, updating `sleeves.csv` with a `portfolio_id` FK.
    *   **Where Addressed:** `technical-design.md` (Sections 6, 8.25, 8.26, 21), `product-requirements.md` (Sections 5, 7, Data model, Changelog), and `product-roadmap.md` (Phase 1, 4).
    *   **Status:** Fully implemented.

*   **Multi-entry Transactions**
    *   **Recommendation:** Define `group_id` and `group_role` for multi-entry transactions like balanced transfers and gross/net splits.
    *   **Where Addressed:** `technical-design.md` (Sections 8.2, 13, 15, 21), `product-requirements.md` (Sections 5, 12, Changelog), and `product-roadmap.md` (Phase 1, 2, 5, 6, Changelog).
    *   **Status:** Fully implemented.

*   **Investment Trades in Unified Ledger**
    *   **Recommendation:** Fold investment buys/sells into the unified transactions ledger as `type = trade` rows and deprecate `Investments/transactions.csv`.
    *   **Where Addressed:** `technical-design.md` (Sections 8.2, 8.9, 21, 24), `product-requirements.md` (Section 5, Changelog), and `product-roadmap.md` (Phase 1, 4, Changelog).
    *   **Status:** Fully implemented.

*   **Account Two-Tier Classification**
    *   **Recommendation:** Retain `account_group` (enum) and `account_type`, and establish `status` as the canonical lifecycle field.
    *   **Where Addressed:** `technical-design.md` (Section 8.21, 21), `product-requirements.md` (Section 5).
    *   **Status:** Fully implemented.

*   **Transaction Additions**
    *   **Recommendation:** Add `sending_asset_id`, `receiving_asset_id`, `liability_id`, `source_id`, `tags` to Transaction, along with `trade` and `credit` types.
    *   **Where Addressed:** `technical-design.md` (Section 8.2, 24).
    *   **Status:** Fully implemented.

*   **Schema-Rename Migration Script**
    *   **Recommendation:** Write a single migration script (`migrate-r6.swift`) to perform the renames automatically.
    *   **Where Addressed:** `product-roadmap.md` (Phase 2 Development Tasks and Changelog).
    *   **Status:** Fully implemented in the roadmap.

## What Was Missed or Incomplete ❌

*   **Data Flow / Pipeline Diagrams**
    *   **Recommendation:** Add a sequence diagram mapping how external data is ingested from a source to raw rows, normalized into `Transaction`, mapped via `Transaction-source`, and used to update `Account`/`Asset`/`Liability` balances.
    *   **Why Outstanding:** No sequence diagrams or data flow pipeline visual mappings were added to `technical-design.md` or any other document.
    *   **Severity:** Medium. The ingestion pipeline is complex and visual documentation is highly valuable for this specific system.

*   **Implement File Organization Proposal**
    *   **Recommendation:** Establish a scalable directory structure under `/docs/architecture/` with files like `index.md`, `core-domain.md`, `containers-and-budgets.md`, `rulesets-and-taxes.md`, and `data-pipelines.md`.
    *   **Why Outstanding:** `technical-design.md` remains a massive monolithic file. The new directory structure and split files were not created.
    *   **Severity:** Medium. As noted in the review, the monolithic file is becoming a bottleneck.

*   **Project Management Document Updates**
    *   **Recommendation:** Add migration tasks for the three renames and two new files to `docs/project-management.md`, and update ticket naming.
    *   **Why Outstanding:** The `project-management.md` file was untouched in this refinement round. It does not reflect any of the Round 6 additions, renames, or required migration tasks.
    *   **Severity:** High. The project management doc is out of sync with the current roadmap and design, missing crucial tasks required to execute the r6 changes.

*   **Prototype Javascript Updates**
    *   **Recommendation:** Update `prototype/data.js` and `prototype/store.js` to rename mock collections (`entities` -> `accountGroups`, etc.), add mock liabilities and portfolios, and add the new transaction fields.
    *   **Why Outstanding:** There are no corresponding tasks added to the roadmap to actually execute these prototype updates, and based on the prompt context, we cannot verify if the JS files were updated directly.
    *   **Severity:** High. If the prototype is the primary vehicle for reviewing these changes, it must be updated to match the new schema.

*   **Live Market Data for Assets**
    *   **Recommendation:** Outline public endpoints for live data related to assets in the next review to replace static file storage.
    *   **Why Outstanding:** While noted as a future item in the review, there are no tasks in the roadmap or notes in the PRD/Tech Design capturing this requirement for a future phase or review.
    *   **Severity:** Low. It's a forward-looking recommendation, but should be tracked somewhere so it isn't lost.

## New Issues Introduced

*   None observed. The implementation was generally very clean and did not introduce regressions in the markdown files updated.

## Recommended Next Steps

1.  **Update Project Management:** Immediately update `docs/project-management.md` to include tasks for the Round 6 schema migrations, the new `migrate-r6.swift` script, and prototype updates. Ensure ticket naming conventions are updated to reflect the new object names.
2.  **Execute the File Organization Proposal:** Create the `/docs/architecture/` directory and break down `technical-design.md` into the recommended smaller domain files (`core-domain.md`, `containers-and-budgets.md`, etc.).
3.  **Draft Pipeline Diagrams:** Create the required sequence diagrams for external data ingestion and normalization and include them in the new `data-pipelines.md` document.
4.  **Track Live Market Data:** Add a note or a deferred task in the roadmap or project management document to research and define read-only price ingestion endpoints.
