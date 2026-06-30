---
name: "swiftui-view-scaffold"
description: "Scaffold a new SwiftUI module view for the macOS app, pre-wired to DESIGN.md tokens, the five-layer architecture, and the v1 component set (NavigationSplitView shell, KPI cards, data tables, detail pane). Use when building any UI/ view in Sources/FinanceWorkspaceApp/ during Phase 5."
metadata:
  author: "open-finance"
  inspired-by: "google-labs-code/design.md"
user-invocable: true
disable-model-invocation: false
---

# SwiftUI View Scaffold

Generate a new presentation-layer view that conforms to the design system and architecture on the
first pass — no retrofitting tokens later.

## Preconditions

1. **Run `design-adherence` first.** No view is scaffolded without clearing the gate.
2. Confirm the **DesignSystem token source exists** at
   `Sources/FinanceWorkspaceApp/DesignSystem/` (`Tokens.swift`, `Typography.swift`,
   `Components/`). If it does not yet exist (pre-Phase-5), create it from the `DESIGN.md` front
   matter **before** the view — every semantic token becomes a `Color`/`Font`/metric constant that
   resolves correctly in light **and** dark. This is the one allowed place to translate tokens to
   code; views never hardcode values.

## Architecture rules (non-negotiable)

- The view lives in the **Presentation layer** (`UI/<Module>/`) and may depend only on **Domain**
  projections — never on Parsing/Platform directly. Five-layer model: File → Parsing → Domain →
  Projection → Presentation.
- A view **renders projections**; it does not compute finance logic. If you need a number that an
  engine doesn't expose, the gap is in the Domain layer — surface it, don't inline it.
- Bind state with `@Observable` `AppState`/module state; navigation via `AppRouter`. Overview is the
  default selection; the sidebar header navigates to it.

## Scaffold contents

Produce, using only DESIGN.md tokens:

1. The `View` struct in `Sources/FinanceWorkspaceApp/UI/<Module>/<Name>View.swift`.
2. Composition from the **component set** (`KPICardView`, `PanelView`, `DataTableView`,
   `StatusChip`, `DetailPaneView`, charts) — match the prototype class contracts in DESIGN.md §Components.
3. **Tabular numerals** (`.monospacedDigit()`) on every numeric value; numeric `Table` columns
   right-aligned.
4. **Traceability** wired: KPI cards tap → their module; table rows select → `DetailPaneView`
   (closed by default) showing source file/row.
5. An **empty state** (`EmptyStateView`) for the data-less case.
6. A `#Preview` in **both** color schemes (`.preferredColorScheme(.light)` and `.dark`).

## Checklist before returning

- [ ] Zero hardcoded colors/sizes — all via `DesignSystem` tokens.
- [ ] Renders correctly in light and dark previews.
- [ ] No Domain/Parsing logic in the view body.
- [ ] Sidebar/detail-pane/keyboard conventions match DESIGN.md §Layout.
- [ ] Matches the prototype reference for this screen (`prototype/` + `docs/_design/`).
