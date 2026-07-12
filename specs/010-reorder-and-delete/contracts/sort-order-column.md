# Contract: `sort_order` CSV column

The externally observable contract for the new column — what any tool (the app, a spreadsheet,
a text editor, a future CLI) may rely on when reading or writing workspace files.

## Applies to

- `Accounts/account-groups.csv` — scope: all group rows.
- `Accounts/accounts.csv` — scope: rows sharing the same `account_group_id`.

## Reading

1. The column is **optional**. A file without it, or a row with an empty cell, is valid.
2. A valid value is a base-10 non-negative integer. Anything else (text, negative, fraction) is
   treated as absent and MAY produce a warning; it MUST NOT fail parsing or block projections.
3. Display order = ascending `sort_order`; rows without a value follow all rows with one, in
   default order (groups: `account_group_id` ascending; accounts: `account_id` ascending).
4. Duplicate values are tolerated: ties break by the default order. Gaps are meaningless.
5. `schema_version` remains `1` — readers MUST NOT require a version bump to accept the column.

## Writing (the app's guarantees)

1. The app only writes the column as part of a user-initiated reorder; it never adds the column
   to a file the user hasn't reordered (SC-002: untouched workspaces stay byte-identical).
2. A reorder write stamps every row in the affected scope with unique gap-of-10 values
   (`10, 20, 30, …`) reflecting the new display order, and changes **no other cell**.
3. Every reorder write is preceded by a timestamped backup and applied atomically; it is refused
   while the file is syncing, stale, conflicted, or read-only.
4. Hand edits are first-class: users may renumber or insert values (e.g., `15` between `10` and
   `20`) in any editor; the app honors them on next scan and normalizes values back to gap-of-10
   on its next reorder write.
