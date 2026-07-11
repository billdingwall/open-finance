# Quickstart: verifying UV-1 sidebar reorder

## Build & unit verification (CLT-only machine)

```bash
swift build                          # Kit + app + CLIs compile
swiftlint --strict                   # must pass before push
# swift test needs full Xcode — runs in macOS CI
```

## Manual walkthrough

```bash
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance   # if needed
swift run fixture-generate    --workspace ~/Finance-Dev --months 12
swift run FinanceWorkspaceApp                                     # DEBUG → local-folder provider
```

1. **US1 — groups**: sidebar › Accounts › Account groups: drag a group to a new position.
   Order updates instantly; quit + relaunch → order retained.
2. **File proof**: open `~/Finance-Dev/Finance/Accounts/account-groups.csv` — every row has a
   unique gap-of-10 `sort_order`; a timestamped backup exists under `.finance-meta/backups/`;
   no other cell changed.
3. **US2 — accounts**: expand a group, drag an account within it. Try dropping onto another
   group → drop refused. Check `accounts.csv`: only that group's rows gained `sort_order`.
4. **US3 — mirroring**: open the Accounts module — group cards and account rows match sidebar
   order; open any account picker/edit-form dropdown — same order.
5. **Accessibility path**: right-click a group/account row → "Move up" / "Move down".
6. **Gating**: while a write preview is open elsewhere (or gate reason set), drag is disabled
   with the standard tooltip reason.
7. **Hand-edit tolerance**: set two groups to the same `sort_order` in a text editor, add a
   non-numeric value on a third → app still loads, deterministic order, at most a warning in
   the validation surface.
8. **Fresh workspace**: bootstrap a new workspace, don't reorder → files contain no
   `sort_order` column and remain byte-identical after browsing.

## Test suites touched

- `Tests/FinanceWorkspaceKitTests/` — mapper/accessor ordering, reorder WritePlan shape,
  invalid-value degradation, round-trip (reorder → parse → same order).
- `Tests/FinanceWorkspaceKitTests/Perf/PerformanceHarness.swift` — reorder write ≤ 1s budget.
- `Tests/FinanceWorkspaceAppTests/` — AppState reorder entry point: optimistic apply, gate
  refusal rollback, projection refresh.
