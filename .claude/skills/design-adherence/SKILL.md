---
name: "design-adherence"
description: "MANDATORY gate before any UI, UX, or frontend-architecture change. Reads DESIGN.md and checks the proposed change against the design system's tokens, components, and Do's & Don'ts. Invoke automatically before proposing or writing any view, style, layout, color, type, chart, or component change in prototype/ or Sources/FinanceWorkspaceApp/."
metadata:
  author: "open-finance"
  inspired-by: "google-labs-code/design.md"
user-invocable: true
disable-model-invocation: false
---

# Design Adherence Gate

You are **strictly forbidden** from proposing or writing UI, UX, or frontend-architecture changes
without first clearing this gate. "UI/UX/frontend" includes: SwiftUI views, `prototype/` HTML/CSS/JS,
colors, typography, spacing, layout, components, charts, icons, motion, and navigation structure.

## When this fires

- Editing or creating anything under `prototype/` or `Sources/FinanceWorkspaceApp/`.
- Adding/altering a component, color, font size, radius, shadow, spacing value, or chart.
- Proposing a new screen, navigation change, or detail-pane behavior.

If you are about to touch any of the above and have **not** read `DESIGN.md` in this session, stop
and run this skill first.

## Procedure (do every step, in order)

1. **Read `DESIGN.md`** — both the YAML front matter (tokens) and the body (rules). It is the single
   source of truth; if it conflicts with older docs, it wins.
2. **Locate the relevant tokens/components.** Map the change to existing semantic tokens
   (`surface-*`, `ink-*`, `accent*`, `pos`/`neg`, status colors) and the component table. Pick the
   nearest existing step on the type/spacing/radius scale — do **not** invent new ones.
3. **Run the Do's & Don'ts checklist** against the change:
   - [ ] Uses **semantic tokens**, never a hardcoded hex/px (so light/dark + sync work).
   - [ ] **Tabular numerals** for every number; numeric table columns right-aligned.
   - [ ] **One accent** only; green/red reserved for money (`pos`/`neg`) and status meaning.
   - [ ] Depth via **borders + system materials**; shadows only on floating surfaces.
   - [ ] No new accent, radius, or one-off font size.
   - [ ] Brand accent is **brand-locked** (`"BrandAccent"`), not `NSColor.controlAccentColor`.
   - [ ] No global filter bar; detail pane stays **closed by default**.
   - [ ] KPIs and rows are **traceable** tap targets to detail/source (constitution #5).
   - [ ] **Native-macOS-first**: `NavigationSplitView`, vibrancy chrome, SF Pro, keyboard nav.
4. **Verify both surfaces stay aligned.** A change to one of {`DESIGN.md` front matter,
   `prototype/styles.css`, SwiftUI tokens, Figma} obligates reconciling the others — note which and,
   if tokens changed, hand off to `design-token-sync` / `figma-css-sync`.
5. **If the change requires something the system doesn't cover**, do **not** improvise in code.
   Propose an edit to `DESIGN.md` first (with a Changelog entry), get it agreed, then implement.

## Output

State explicitly: "Design-adherence check: PASS/NEEDS-DESIGN-UPDATE", the tokens/components used, and
any Don'ts you had to design around. Only then proceed to the change. Never silently skip the gate.
