# Quickstart: verifying UV-2 delete-in-edit-modal

## Build & unit verification (CLT-only machine)

```bash
swift build            # compiles; swift test runs in macOS CI
```

## Manual walkthrough

```bash
swift run fixture-generate --workspace ~/Finance-Dev --months 12   # if needed
swift run FinanceWorkspaceApp
```

1. **US1 — clean delete**: edit an account with no transactions (or add one first) → the form
   footer shows a leading, red **Delete** action → activating it closes the form and opens the
   write preview showing the file, the exact row, and the backup note → confirm → the account is
   gone from the sidebar, cards, and pickers; a backup exists under `.finance-meta/backups/`.
2. **US1 — add mode**: open "New account" → no Delete action anywhere in the form.
3. **US2 — referenced delete**: edit a category used by transactions → Delete → the reassignment
   picker lists the referencing collections with counts → choose a target → one preview shows
   delete + reassignments → confirm → applied atomically.
4. **US2 — required reference**: edit an account group that still contains accounts → Delete →
   the picker offers other groups only (no unlink); with a single group in the workspace the
   delete cannot complete.
5. **Cancel paths**: cancel the form / the picker / the preview → files byte-identical each time.
6. **US3 — gating**: with writes blocked (sync chip busy), the Delete action is disabled with the
   gate reason tooltip.
7. **Out-of-scope forms**: edit a goal or budget → no Delete action (detail-pane delete still
   works for them).

## Test suites touched

- `Tests/FinanceWorkspaceAppTests/DeleteInEditFormTests.swift` (new) — entry-point parity with
  the detail-pane path (SC-002), whitelist + add-mode suppression, cancel byte-identity,
  gating.
