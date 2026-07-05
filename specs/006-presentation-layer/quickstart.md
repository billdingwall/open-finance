# Quickstart — Presentation Layer (006)

## Build & run (CLT-only box, DEBUG local-folder provider)

```bash
swift build                                                # everything, incl. the app views
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance
swift run fixture-generate    --workspace ~/Finance-Dev --months 12
swift run FinanceWorkspaceApp                              # real shell: Overview landing
```

Expected: Overview dashboard with 5 live KPI cards, issues + sync chips in the header, sidebar
groups (no Overview row), detail pane closed.

## Reconcile views against engines (SC-001/004)

```bash
swift run overview-dashboard  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run accounts-overview   --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run budget-overview     --workspace ~/Finance-Dev/Finance --period 2026-06
swift run savings-overview    --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run portfolio-overview  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run benchmark-overview  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
swift run tax-overview        --workspace ~/Finance-Dev/Finance --tax-year 2026
```

Values on screen must match the CLI output for the same as-of date.

## Read-only proof (SC-005)

```bash
tar -cf /tmp/ws-before.tar -C ~/Finance-Dev Finance
# ... full app session: browse all modules, open previews, quit ...
tar -cf /tmp/ws-after.tar  -C ~/Finance-Dev Finance
cmp /tmp/ws-before.tar /tmp/ws-after.tar && echo "read-only ✅"
```

## Tests & lint

```bash
swift test        # macOS CI (full Xcode); includes FinanceWorkspaceAppTests
swiftlint --strict
```

## App target (US8 — Xcode machine or CI)

```bash
brew install xcodegen
xcodegen generate --spec App/project.yml
xcodebuild build -project App/FinanceWorkspace.xcodeproj -scheme FinanceWorkspace \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Milestone 5 demo script

Walk `docs/test-plans.md` user flows against the fixture workspace: sidebar + keyboard-only
navigation to every view; KPI → detail → source-inspector → "Reveal in Finder" chain in each
module; heat-map toggle; dark mode (System Settings → Appearance); empty-workspace launch
(freshly bootstrapped, no fixtures) shows designed empty states.
