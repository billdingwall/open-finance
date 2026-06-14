# Gap Analysis Report: Open Finance Prototype vs Requirements

## Executive Summary

This report documents the gap analysis between the product requirements (`docs/product-requirements.md`), the technical design (`docs/technical-design.md`), and the current state of the prototype (`prototype/`). The prototype has been updated to address several glaring gaps, particularly concerning missing interactions and local state persistence, but some differences remain.

## Current State

The prototype is a static HTML/JS/CSS client application. It mimics a native macOS interface and provides views for Overview, Accounts, Budget, Savings, Investments, Business, and Tax.

Before the recent audit, the prototype suffered from several key issues:
- **Missing Persisted State:** The mock data (`DATA`) was loaded statically. Any state changes (like adding items) would reset on page reload, making it impossible to evaluate multi-step workflows across sessions.
- **Incomplete Actions:** Several primary call-to-action buttons were either missing click handlers or displaying "Coming soon" messages.
- **Missing Views:** Some views like "Indexing Progress", "Settings", and other auxiliary screens were defined but not implemented, just showing a vague "Coming in this sprint" message.

## Updates Made During Audit

To address the glaring gaps in user flows and app states, the following updates were applied to the prototype:

1. **Local Storage Integration:**
   - Modified `prototype/data.js` to initialize the `DATA` object from `localStorage` if it exists.
   - Added `saveData()` and `resetData()` global functions to allow state persistence.
   - The app now supports continuous user flows using mock data across reloads.

2. **Implemented Missing Actions:**
   - **Accounts Module:** Replaced the static "Add account (coming soon)" button in the empty state with a functional "Add account" button that populates the store with a mock checking account and redirects to the accounts view.
   - **Investments Module:** Replaced the static "Add Asset" button in the Personal Entity accounts view with an action that adds a mock Apple (AAPL) investment asset and navigates to the updated view.

3. **Improved Unimplemented View Stubs:**
   - Replaced the generic "Coming in this sprint" text with a clearer stub UI indicating that the view is under construction (🚧).

## Remaining Gaps (Prototype vs. Requirements)

While the prototype now handles state and basic actions better, several gaps remain when compared to the full PRD and Technical Design:

1. **Full CRUD Operations:**
   - While "Add" actions have been mocked for Accounts and Assets, the prototype lacks full Create, Read, Update, Delete (CRUD) flows for all entities (e.g., Transactions, Categories, Budget Items). The current implementation hardcodes the added mock items instead of providing an input form.
2. **File System Mocking:**
   - The requirements specify a file-first architecture (CSV/Markdown). The prototype uses a JSON-based state (`DATA`). While this is expected for a web prototype, it means file validation, conflict resolution, and file repair flows cannot be fully evaluated in this environment.
3. **Markdown Rendering:**
   - The PRD lists Markdown viewing as a requirement, but the prototype lacks a robust inline Markdown renderer for notes.
4. **Calculations and Projections:**
   - The prototype uses pre-calculated totals and projections. It does not implement the actual domain logic required to calculate YTD Net Income, Monthly Inflow, or Investment Returns from raw transactions, which is a key part of the Domain and Projection layers specified in the tech design.

## Recommendations for Next Steps

- **Flesh out Forms:** Implement actual input forms for the "Add" actions in the prototype to better evaluate data entry UX.
- **Review Pre-Build Items:** Address the open decisions in `docs/_notes/consistency-audit.md` before starting the native macOS development.
- **Native Implementation:** Proceed with Phase 1 of the roadmap (Foundation & Architecture) in Swift, as the prototype has served its purpose for UX validation.
