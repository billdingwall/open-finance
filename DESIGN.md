---
# DESIGN.md — Open Finance design system
# Machine-readable token layer (front matter) + human-readable rationale (body).
# Framework-agnostic: every token maps to BOTH a CSS custom property (prototype)
# and a SwiftUI token (the real macOS app). Keep the two in lockstep — see §Token Sources.
name: Open Finance
mode: light-and-dark
platform: macOS 15+ (SwiftUI) · static HTML prototype as living reference
direction: native-macOS-first   # system materials, SF Pro, semantic system colors, single brand accent

colors:
  # token: { light, dark, css, swiftui }  — values are reference; CSS vars are the source of truth.
  window-bg:        { light: "#eef2f7", dark: "#1c1d20", css: "--bg",            swiftui: "Color(NSColor.windowBackgroundColor)" }
  surface:          { light: "#ffffff", dark: "#2a2b2e", css: "--surface",       swiftui: "Color(NSColor.textBackgroundColor)" }
  surface-raised:   { light: "#f8f9fb", dark: "#303134", css: "--surface-2",     swiftui: "Color(NSColor.controlBackgroundColor)" }
  surface-tint:     { light: "#fbfcfe", dark: "#333438", css: "--surface-3",     swiftui: "—" }
  surface-sunken:   { light: "#f3f5f9", dark: "#252629", css: "--surface-sunken",swiftui: "Color(NSColor.underPageBackgroundColor)" }
  sidebar:          { light: "material/regular over #f8f9fb", dark: "material/regular over #232427", css: "--surface-2", swiftui: ".regularMaterial (NSVisualEffectView .sidebar)" }
  border:           { light: "#d7dde7", dark: "#3a3b3f", css: "--border",        swiftui: "Color(NSColor.separatorColor)" }
  border-soft:      { light: "#e3e8ef", dark: "#313236", css: "--border-soft",   swiftui: "Color(NSColor.separatorColor).opacity(0.6)" }
  border-strong:    { light: "#c4cdda", dark: "#47484c", css: "--border-strong", swiftui: "—" }
  ink-1:            { light: "#0f172a", dark: "#f5f6f8", css: "--ink-1",         swiftui: "Color(NSColor.labelColor)" }
  ink-2:            { light: "#1f2937", dark: "#e4e5e8", css: "--ink-2",         swiftui: "Color.primary" }
  ink-3:            { light: "#374151", dark: "#c7c9ce", css: "--ink-3",         swiftui: "—" }
  ink-4:            { light: "#4b5563", dark: "#abaeb5", css: "--ink-4",         swiftui: "—" }
  muted:            { light: "#6b7280", dark: "#9aa0a8", css: "--muted",         swiftui: "Color(NSColor.secondaryLabelColor)" }
  muted-2:          { light: "#94a3b8", dark: "#71777f", css: "--muted-2",       swiftui: "Color(NSColor.tertiaryLabelColor)" }
  accent:           { light: "#3651d3", dark: "#7088f2", css: "--accent",        swiftui: "Color(\"BrandAccent\")  // brand-locked, NOT NSColor.controlAccentColor" }
  accent-soft:      { light: "#e8eefc", dark: "#293052", css: "--accent-soft",   swiftui: "—" }
  accent-border:    { light: "#b9c8f2", dark: "#3c477a", css: "--accent-border", swiftui: "—" }
  accent-ink:       { light: "#1e3aab", dark: "#b4c2f8", css: "--accent-ink",    swiftui: "—" }
  on-accent:        { light: "#ffffff", dark: "#1c1d20", css: "--on-accent",     swiftui: "—  # text on accent fills; dark uses near-black for WCAG AA (white on #7088f2 is only 3.2:1)" }
  ok:               { light: "#15803d", dark: "#30d158", css: "--ok",            swiftui: "Color(NSColor.systemGreen)" }
  ok-soft:          { light: "#dcfce7", dark: "#10331f", css: "--ok-soft",       swiftui: "—" }
  warn:             { light: "#b45309", dark: "#ff9f0a", css: "--warn",          swiftui: "Color(NSColor.systemOrange)" }
  warn-soft:        { light: "#fef3c7", dark: "#3a2a09", css: "--warn-soft",     swiftui: "—" }
  err:              { light: "#b91c1c", dark: "#ff453a", css: "--err",           swiftui: "Color(NSColor.systemRed)" }
  err-soft:         { light: "#fee2e2", dark: "#3a1715", css: "--err-soft",      swiftui: "—" }
  info:             { light: "#1e40af", dark: "#0a84ff", css: "--info",          swiftui: "Color(NSColor.systemBlue)" }
  info-soft:        { light: "#dbeafe", dark: "#081a30", css: "--info-soft",     swiftui: "—  # dark deepened 2026-07-07: info on the old #0e2747 was 4.1:1 (AA fail)" }
  pos:              { light: "#15803d", dark: "#30d158", css: "--pos",           swiftui: "Color(NSColor.systemGreen)  // money in / gain" }
  neg:              { light: "#b91c1c", dark: "#ff453a", css: "--neg",           swiftui: "Color(NSColor.systemRed)    // money out / loss" }

typography:
  family-ui:   "SF Pro Text / SF Pro Display (system) — CSS fallback: Inter, -apple-system, 'Segoe UI', sans-serif"
  family-mono: "SF Mono (system) — CSS fallback: ui-monospace, Menlo, Consolas, monospace"
  base-size-px: 13
  numerals: "tabular (font-variant-numeric: tabular-nums) for ALL money, counts, dates"
  scale:
    page-title:  { px: 20,   weight: 600, tracking: "-0.01em", swiftui: ".title2.weight(.semibold)" }
    kpi-value:   { px: 22,   weight: 600, tracking: "-0.01em", swiftui: ".title.weight(.semibold).monospacedDigit()" }
    section:     { px: 15,   weight: 600, tracking: "0",       swiftui: ".headline" }
    panel-title: { px: 12.5, weight: 600, tracking: "0",       swiftui: ".subheadline.weight(.semibold)" }
    body:        { px: 13,   weight: 400, tracking: "0",       swiftui: ".body (13pt)" }
    table:       { px: 12.5, weight: 400, tracking: "0",       swiftui: ".callout.monospacedDigit() for numeric cells" }
    overline:    { px: 11,   weight: 600, tracking: "0.04em",  transform: uppercase, swiftui: ".caption.weight(.semibold) + .textCase(.uppercase)" }
    caption:     { px: 11,   weight: 400, tracking: "0",       swiftui: ".caption" }

rounded:
  sm:      { px: 6,   css: "--radius-sm",  swiftui: "6" }
  DEFAULT: { px: 10,  css: "--radius",     swiftui: "10" }
  lg:      { px: 14,  css: "--radius-lg",  swiftui: "14" }
  pill:    { px: 999, css: "999px",        swiftui: "Capsule()" }

spacing:
  unit-px: 4
  scale-px: [2, 4, 6, 8, 12, 14, 16, 18, 24, 32]
  row-height-px: { value: 30, css: "--row-h", note: "dense data rows" }
  content-padding-px: "18 24 (top/bottom · sides)"
  sidebar-width-px: 248
  detail-pane-width-px: "360–420 (slide-over, closed by default)"
  min-window-px: 900

elevation:
  philosophy: "Native-first: prefer borders + system materials over heavy shadows. Shadows are subtle and reserved for floating surfaces (modals, popovers, the detail slide-over)."
  shadow-sm: { css: "--shadow-sm", value: "0 1px 2px rgba(15,23,42,.04)" }
  shadow:    { css: "--shadow",    value: "0 1px 2px rgba(15,23,42,.04), 0 4px 12px rgba(15,23,42,.04)" }
  materials: "Sidebar = .regularMaterial (vibrancy). Toolbar = window titlebar material. Modals/popovers = .thickMaterial over a dimming scrim."

components:
  sidebar-nav-item:   "248px rail · collapsible groups · active = accent-soft bg + accent-ink text · count badge right-aligned"
  kpi-card:           "surface-raised · 1px border · radius DEFAULT · overline label + 22px tabular value + delta(pos/neg/flat) · whole card is the tap target → module"
  panel:              "surface · 1px border · radius DEFAULT · panel-head (title + sub + actions) over panel-body"
  data-table:         "12.5px · sticky uppercase header on surface-tint · 30px rows · numbers right-aligned + tabular · row hover = surface-sunken · selected = accent-soft"
  status-chip:        "pill · ok/warn/err/info soft-bg variants · leading status dot · sync + issue state"
  tag:                "pill · same semantic variants as chip · inline record labels"
  button:             "primary (accent fill) · secondary (surface + border) · ghost (transparent)"
  filter-pill:        "pill · label + value + caret · active = accent-soft (inline period/account selection only; no global filter bar in v1)"
  breadcrumb:         "11px muted · crumb / sep / crumb above the page title"
  detail-pane:        "right slide-over · closed by default globally · opens on main-panel selection · inspector / source-row / repair-preview / edit-form surfaces"
  chart:              "chart-wrap (tall 230 / short 140) · single-accent series · tabular axis labels · heat-map pos/neg cell scale"
  modal-form:         "centered over scrim · stacked modal-field (label + control) · used for add/edit flows"
  empty-state:        "glyph + title + one-line message + optional CTA · one per data-less surface"
  step-indicator:     "N dots/segments on the onboarding wizard header · done = accent fill · current = accent ring · upcoming = border on surface-sunken · caption 'Step n of N' in muted"
  onboarding-wizard:  "modal-form variant: one centered lg-radius card (max 520px) over the window bg · step-indicator header · one step visible at a time · Back ghost / Continue primary footer · iCloud state uses status-chip semantics"
---

# Open Finance — Design System

> **This file is the single source of design truth.** Read it before proposing or making any
> UI, UX, or frontend-architecture change. The `.claude/skills/design-adherence` skill enforces
> this; do not bypass it. When a change conflicts with this document, update this document first
> (with a Changelog entry) — never let the code and the system silently diverge.

## Scope & boundaries

`DESIGN.md` owns the **visual design language and UI/UX component contracts** — tokens (color,
type, spacing, radius, elevation), component anatomy, and native-macOS presentation patterns,
expressed once for both `prototype/styles.css` (CSS) and the SwiftUI app.

It does **not** own software architecture. Data flow, the file/"local-first" data model, CSV/MD
schemas, validation rules, and read/write/repair pipelines live in `docs/technical-design.md` and
`docs/architecture/` (there is no database — constitution principle #1). When a UI component needs a
value, it consumes a **Domain-layer projection** defined there; design it, don't compute it here.

## Overview

Open Finance is a **native macOS personal-finance workspace** (SwiftUI, iCloud-backed) that sits
over CSV/Markdown files the user owns. The design language is therefore **calm, dense, and
trustworthy** — a professional desktop tool for reading and reconciling real money, not a
consumer dashboard. Every visual decision serves legibility of financial data and fidelity to the
underlying files.

**Direction: native macOS-first.** We lean into the platform — `NavigationSplitView`, sidebar
vibrancy, SF Pro, system semantic colors (green/red/orange/blue), keyboard navigation, and the
right-hand inspector pattern — and layer a **single brand indigo accent** on top for identity and
selection. We do *not* reinvent macOS chrome. This honors constitution principle **#3 "Native over
generic."**

This system governs two surfaces from one token set:

| Surface | Role | Token expression |
|---|---|---|
| `prototype/` (HTML/CSS) | the **living reference** — review look & flow here first | CSS custom properties in `prototype/styles.css` |
| `Sources/FinanceWorkspaceApp/` (SwiftUI) | the **real app** (Phase 5) | Swift tokens in `Sources/FinanceWorkspaceApp/DesignSystem/` (to be created) |

The front matter above is the machine-readable contract; the sections below are the rationale and
rules. Tokens are **semantic** (`surface-sunken`, `ink-2`, `pos`) not literal (`gray-100`) so the
dark palette and any future theme drop in without renaming.

## Colors

Color is **functional**, never decorative. The palette is layered neutrals + one accent + the
financial/status semantics. Full light **and** dark values live in the front matter; the rules:

**Surfaces (back-to-front):** `window-bg` → `surface-sunken` → `surface` → `surface-raised`. The
window/under-page is the coolest; content panels sit on `surface`; cards and table headers lift
onto `surface-raised`/`surface-tint`. The **sidebar uses a vibrancy material**, not a flat fill.

**Text (ink ramp):** `ink-1` for headings/values, `ink-2` for body, `muted` for labels/secondary,
`muted-2` for tertiary/placeholder. Never put `muted-2` on `surface-sunken` — contrast fails.

**Accent (brand indigo):** exactly one accent. Use it for primary actions, active nav, selection,
single-series charts, and links. It is **brand-locked** — bind it to a named asset
(`"BrandAccent"`), **not** `NSColor.controlAccentColor`, so the app's identity is stable regardless
of the user's system accent. `accent-soft`/`accent-border`/`accent-ink` are the selection/hover set.

**Financial semantics:** `pos` (green) = money **in** / gain; `neg` (red) = money **out** / loss.
These map to `systemGreen`/`systemRed`. This is the only place green/red carry meaning beyond
status — apply them to amounts, deltas, and variance, always with **tabular numerals**.

**Status semantics:** `ok`/`warn`/`err`/`info` (+ their `-soft` backgrounds) drive sync state,
validation severity, and issue chips. Map to `systemGreen`/`systemOrange`/`systemRed`/`systemBlue`
so they track platform conventions in both modes.

**Dark mode is first-class, not an afterthought.** Every token has a dark value tuned for an OLED-
ish neutral (`window-bg #1c1d20`), brighter accent (`#7088f2`) and status colors (`systemRed`
brightens to `#ff453a`) for contrast on dark surfaces. Never hardcode a hex in a view — resolve the
semantic token so both modes are correct for free.

## Typography

**SF Pro is canonical** (the macOS system font); Inter is only the web-prototype stand-in so the
browser mock reads correctly off-Mac. In SwiftUI, prefer the semantic `Font` styles in the mapping
(`.title2`, `.headline`, `.callout`) so Dynamic Type and the platform metrics apply; the px sizes
in the front matter are the design intent and the prototype's literal values.

- **Tabular numerals everywhere numbers live** — money, counts, dates, percentages, table cells,
  KPI values, deltas. `.monospacedDigit()` in SwiftUI; `font-variant-numeric: tabular-nums` in CSS.
  Misaligned digits in a finance table read as a bug.
- **Overlines** (11px, 600, uppercase, +0.04em tracking) label KPI cards, table headers, and panel
  section labels. They are `muted`, never `ink-1`.
- **Page title** is 20px/600; there is one per screen, preceded by a breadcrumb.
- Keep the type ramp tight — six body/label steps. Resist inventing new sizes; pick the closest
  step.

## Layout

- **Shell:** `NavigationSplitView` — a 248px **sidebar** (collapsible groups), the main content
  column, and a **right detail pane that is closed by default globally** (locked decision) and
  opens on selection in the main panel. Minimum window width 900px.
- **Overview is the default landing** screen, reached via the sidebar header ("Finance Dashboard"),
  not a nav row.
- **Density is intentional.** 30px data rows, 13px base, tight 4px-unit spacing. This is a
  power-user tool; whitespace serves grouping, not breathing room for its own sake.
- **Content padding** is 18px top/bottom · 24px sides. **KPI grids** are equal columns (3–7) with a
  12px gap. **Panels** stack with a 16px gap; two-up rows use `row2`/`row-2-1`.
- **The status cluster** (sync chip + issue chip) lives in the top region; **local actions** (Import,
  Add, Export) sit right-aligned on the page-title row. There is **no global filter bar in v1** —
  only inline period/account selectors where a screen intrinsically needs them.

## Elevation & Depth

Depth is communicated **primarily by borders and material**, secondarily by shadow — the macOS way.

- **Chrome** (sidebar, toolbar) uses **vibrancy materials**, not flat fills or borders alone.
- **Panels & cards** are defined by a 1px `border` on a lifted `surface`/`surface-raised`, not a
  drop shadow. Selection adds an inset accent ring, not elevation.
- **Floating surfaces only** — modals, popovers, and the detail slide-over — earn a real shadow
  (`--shadow`) over a dimming scrim. Nothing inline casts a shadow.
- Keep shadow opacity in the single-digit-percent range; heavy shadows read as non-native.

## Shapes

One radius scale: `sm 6` (chips/buttons/inputs), `DEFAULT 10` (cards/panels), `lg 14` (modals/large
surfaces), `pill 999` (status chips, tags, filter pills, sync indicators). Match macOS's restrained
corner rounding — never exceed `lg` on a rectangular surface, and use full pills only for
genuinely pill-shaped affordances.

## Components

Each component is the contract for both surfaces. Build the SwiftUI view to match the prototype
class; keep names aligned so the token-sync and design-adherence skills can cross-check.

| Component | Anatomy & rules | Prototype class | SwiftUI view (Phase 5) |
|---|---|---|---|
| **Sidebar nav item** | Collapsible group → indented items; active = `accent-soft` bg + `accent-ink` text + medium weight; right-aligned count badge | `.nav-item` / `.nav-group` | `NavigationSidebarView` rows |
| **KPI card** | Overline label + 22px tabular value + optional `pos/neg/flat` delta + foot note; **whole card is the tap target** → its module; selected = inset accent ring | `.kpi-card` | `KPICardView` |
| **Panel** | `panel-head` (12.5px title + muted sub + right actions) over `panel-body`; 1px border, radius DEFAULT | `.panel` | `PanelView` / `GroupBox` |
| **Data table** | Sticky uppercase 10.5px header on `surface-tint`; 30px rows; numbers right-aligned + tabular; hover `surface-sunken`; selected `accent-soft`; **every row is traceable** to its source file/row | `.tbl` | `DataTableView` (`Table`) |
| **Status chip** | Pill, leading dot, `ok/warn/err/info` soft variant; sync state + issue count | `.status-chip` | `StatusChip` |
| **Tag** | Pill, same semantic variants; inline record labels (e.g. `BX-` business, schema flags) | `.tag` | `TagView` |
| **Button** | `primary` (accent fill, white text) · `secondary` (surface + border) · `ghost` (transparent). One primary per action context | `.btn` / `.btn-primary` / `.btn-ghost` | `.buttonStyle(...)` |
| **Filter pill** | Label + value + caret; active = `accent-soft`. Inline selection only | `.filter` | `PeriodSelectorView` |
| **Breadcrumb** | 11px muted, `crumb / sep / crumb`, above the title | `.breadcrumb` | `BreadcrumbView` |
| **Detail pane** | Right slide-over, **closed by default**; surfaces: inspector, source-row preview, repair preview, edit form; edit/delete at the bottom for right-panel objects | `.inspector` | `DetailPaneView` |
| **Chart** | `chart-wrap` (tall 230 / short 140); single-accent series; tabular axis labels; **heat-map** uses `pos`/`neg` cell scale with an S&P 500 comparison row | `.chart-wrap` / `.heat-map-table` | Swift Charts (`PieChartView`, `SparklineView`, `HeatMapTableView`) |
| **Modal form** | Centered over scrim; stacked `modal-field` (label + control); add/edit flows; preview before write | `.modal` | sheet + `Form` |
| **Empty state** | Glyph + title + one-line message + optional CTA; one per data-less surface | `.empty-inspector` | `EmptyStateView` |
| **Step indicator** | Dots/segments above the wizard title: done = `accent` fill, current = `accent` ring, upcoming = `border` on `surface-sunken`; "Step n of N" caption in `muted` | *(app-only)* | `StepIndicatorView` |
| **Onboarding wizard** | `modal-form` variant: one centered card (radius `lg`, max 520px, `--shadow` — it floats) over `window-bg`; step-indicator header; single step visible; footer = Back (ghost) + Continue (primary); iCloud setup state rendered with `status-chip` semantics (`ok`/`warn`/`err`); **cannot be dismissed until complete** | *(app-only)* | `OnboardingView` |

**Traceability is a design requirement, not just engineering** (constitution #5): every KPI links to
a detail view, and every detail row links to its source file + row. Design KPI cards and table rows
as tap targets accordingly.

## Motion

Restrained and fast. Hover/selection transitions 80–120ms ease. The detail pane and modals animate
in over ~150–200ms. No bouncing, no decorative motion — this is a finance tool; movement only
confirms a state change.

## Do's and Don'ts

**Do**
- Read this file (and run `/design-adherence`) before any UI/UX/frontend change.
- Resolve **semantic tokens**; let light/dark and theming come for free.
- Use **tabular numerals** for every number; **right-align** numeric table columns.
- Use **one accent**; reserve green/red for money & status meaning.
- Prefer **system materials + borders** for depth; reserve shadows for floating surfaces.
- Keep the type ramp and spacing scale tight — pick the nearest existing step.
- Make KPIs and rows **traceable** tap targets to their detail/source.

**Don't**
- Don't hardcode hex/px in a view — reference the token (breaks dark mode and sync).
- Don't introduce a second accent, a new radius, or a one-off font size.
- Don't bind the brand accent to `NSColor.controlAccentColor` — it's brand-locked.
- Don't add a global filter bar (deferred to V2) or open the detail pane by default.
- Don't add drop shadows to inline cards/panels — borders do that job.
- Don't reach for green/red as decoration; they mean gain/loss and severity.
- Don't let the prototype CSS and the SwiftUI tokens drift — run `/design-token-sync`.

## Token Sources (keep in lockstep)

| Layer | File | Status |
|---|---|---|
| **Front matter (this file)** | `DESIGN.md` | source of truth for *intent* |
| **CSS variables** | `prototype/styles.css` `:root` | source of truth for the *prototype* |
| **SwiftUI tokens** | `Sources/FinanceWorkspaceApp/DesignSystem/Tokens.swift` | created in Phase 5; must mirror the front matter |
| **Figma variables** | Figma Desktop (via figma-cli) → `docs/_design/tokens/` (DTCG/W3C) | sync with `/figma-css-sync` |

When any one changes, reconcile the others in the same change. The `design-token-sync` and
`figma-css-sync` skills automate the diff.

## Changelog

- **2026-07-07 — v1.3** — WCAG AA contrast audit (008 US5 T040) across every token pair the app
  uses, light + dark. **Fixed**: dark `info-soft` deepened `#0e2747` → `#081a30` (info text was
  4.11:1); new **`on-accent`** token (light white / dark `#1c1d20`) for text on accent fills —
  white on the dark accent was 3.23:1, so dark primary buttons now use near-black text (5.21:1);
  **`muted-2` is decorative/placeholder-only** — it fails AA on every surface in light mode
  (≤2.6:1), so all meaningful text at that step moved up to `muted` (the existing "never on
  surface-sunken" rule generalizes). **Documented marginals** (≥3:1, large/bold or borderline;
  revisit at the launch design pass): light `muted` on `window-bg` 4.30:1, dark `accent` as text
  on `surface` 4.38:1. Prototype note: `styles.css` carries light values only, so only the
  `on-accent` variable needs adding when the prototype next syncs (its dark mode is unimplemented).
- **2026-07-06 — v1.2** — First-launch onboarding contracts added: **step-indicator** (done =
  accent fill / current = accent ring / upcoming = border on `surface-sunken`; muted "Step n of N"
  caption) and **onboarding-wizard** (a `modal-form` variant — one centered `lg`-radius card,
  max 520px, real shadow as a floating surface, over `window-bg`; ghost Back / primary Continue;
  iCloud availability states expressed with the existing `status-chip` `ok`/`warn`/`err`
  semantics; non-dismissable until the flow completes). No new tokens — both components compose
  the existing color/type/radius/elevation scales, so `prototype/styles.css` and Figma need no
  token sync (a prototype mock of the wizard can be added when the prototype next updates).
- **2026-07-04 — v1.1** — Phase 5 SwiftUI token layer shipped
  (`Sources/FinanceWorkspaceApp/DesignSystem/` — Tokens/Typography/Components, mirroring the
  front matter 1:1; brand accent expressed as a dynamic light/dark color from the token hexes,
  since the SwiftPM target has no asset catalog). New conventions settled during the build:
  **value-provenance tag colors** (imported = `info-soft`, derived = `surface-sunken`/muted,
  repaired = `warn-soft`, user-edited = `accent-soft` — red stays reserved for money/severity);
  **heat-map cell intensity** = pos/neg at `opacity(0.08 + 0.32 × min(|growth| / 25%, 1))`, typed
  no-data cells on `surface-sunken`; **categorical chart ramp** = accent at opacity steps
  `[1.0, .75, .55, .4, .28, .18]`; previews use the macro-free `PreviewProvider` form (light +
  dark) so the CLT-only box builds. Detail pane = native `.inspector` slide-over.
- **2026-06-30 — v1.0** — Initial system. Native-macOS-first direction; full light + dark token set
  derived from `prototype/styles.css`; framework-agnostic CSS↔SwiftUI mapping; component contracts
  for the v1 module set. Authored alongside the `design-adherence`, `swiftui-view-scaffold`,
  `design-token-sync`, `chart-styling`, and `figma-css-sync` skills.
