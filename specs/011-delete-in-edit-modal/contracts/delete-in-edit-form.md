# Contract: Delete action in the edit modal (UI)

The user-facing behavioral contract for the `EntityEditForm` Delete entry point (spec 011 UV-2).

## Presence

| Condition | Delete action |
|---|---|
| Editing an existing account, account group, or category | **Shown** |
| Add mode (`isNew` — any entity) | **Absent** |
| Editing any other entity type (goal, budget, asset, …) | **Absent** (out of scope; detail-pane delete unchanged) |

## Placement & appearance

1. Leading-aligned in the form footer, visually separated from Cancel/Save (trailing) — it can
   never be hit by muscle memory aiming at Save.
2. Destructive semantics: system destructive role + the `err` semantic token; secondary-button
   chrome matching the detail pane's Edit/Delete pair. No new tokens (DESIGN.md `modal-form`
   note DA-011-1).

## Behavior

3. Activating Delete closes the form (unsaved field edits are discarded) and enters the
   **standard delete pipeline** — the same one the detail pane uses: reference scan → picker
   (referenced) or straight to preview (unreferenced) → atomic apply with timestamped backup.
   Zero divergence from a detail-pane delete of the same entity.
4. The preview always shows the **on-disk** row being removed (the form's unsaved edits never
   appear in it); drift between opening the preview and applying refuses the write.
5. Required references (e.g. an account's group) offer reassignment only — never unlink. If no
   valid target exists (deleting the last group while accounts remain), the delete cannot be
   confirmed and the picker says why.
6. Cancel at any stage (form, picker, preview) changes nothing on disk.

## Gating

7. While writes are blocked (syncing, read-only, pending write), Delete is disabled with the
   standard gate reason as help text — never silently inert, never active while gated.
