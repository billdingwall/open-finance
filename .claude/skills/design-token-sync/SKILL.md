---
name: "design-token-sync"
description: "Detect and fix drift between the three token sources — DESIGN.md front matter, prototype/styles.css :root variables, and the SwiftUI DesignSystem tokens. Use after any change to colors, typography, spacing, radius, or shadows, or to audit that the prototype and the app agree."
metadata:
  author: "open-finance"
  inspired-by: "google-labs-code/design.md"
user-invocable: true
disable-model-invocation: false
---

# Design Token Sync

The design system has three token expressions that **must** stay in lockstep. This skill diffs them
and reconciles drift. `DESIGN.md` front matter is the source of truth for *intent*;
`prototype/styles.css` is the source of truth for the *prototype's* rendered values.

## The three sources

1. **`DESIGN.md` front matter** — semantic tokens with `light`/`dark`/`css`/`swiftui` per entry.
2. **`prototype/styles.css` `:root`** (and any `@media (prefers-color-scheme: dark)` block) — the
   `--token` custom properties.
3. **`Sources/FinanceWorkspaceApp/DesignSystem/Tokens.swift`** — the Swift constants (Phase 5+).

## Procedure

1. **Parse all three.** Build a table keyed by semantic token name. For each, collect: front-matter
   `light`/`dark`, the matching `--css-var` value (light + dark), and the Swift constant.
2. **Diff** and report drift in three buckets:
   - **Value drift** — same token, different hex/px across sources.
   - **Missing token** — present in one source, absent in another (e.g. a dark value not yet in CSS,
     or a Swift constant with no front-matter entry).
   - **Naming drift** — a `--css-var` whose name no longer matches the front-matter `css:` field.
3. **Reconcile toward intent.** Unless told otherwise, treat `DESIGN.md` front matter as canonical
   for *which tokens exist and their semantic names*, and `prototype/styles.css` as canonical for
   *the rendered light values* (it's the reviewed reference). Propose the minimal edits to bring the
   others in line; never silently pick a winner — show the diff and the chosen direction.
4. **Apply** the agreed edits to whichever sources are stale, in one change.
5. **Confirm** by re-diffing: report "Token sync: CLEAN" with a per-source token count, or the
   remaining intentional exceptions (e.g. tokens with `swiftui: "—"` that map to a system color).

## Rules

- A token may **never** be a literal hex/px in a view or component — only in these three sources.
- Every token needs a **dark** value; flag any missing one (the system is `mode: light-and-dark`).
- Don't add a token to one source without adding it to the front matter first.
- After syncing colors/type, hand charts to `chart-styling` and Figma to `figma-css-sync` if those
  surfaces consume the changed tokens.
