---
name: "chart-styling"
description: "Apply the Open Finance design language to charts — Swift Charts in the app and Chart.js in the prototype. Enforces the single-accent palette, tabular axis labels, pos/neg + heat-map color scale, and benchmark comparison conventions. Use when building or editing any pie, bar, sparkline, or heat-map visualization."
metadata:
  author: "open-finance"
  inspired-by: "google-labs-code/design.md"
user-invocable: true
disable-model-invocation: false
---

# Chart Styling

Charts in a finance tool are read for **values, not vibes**. Style every visualization to the system
so it reads as data, not decoration. Covers Swift Charts (`PortfolioEngine` views, Phase 5) and the
prototype's Chart.js (`prototype/vendor/chart.umd.js`).

## Preconditions

Run `design-adherence` first. Resolve all colors from DESIGN.md tokens — never a raw hex in a chart
config.

## Palette rules

- **Single-series charts use the brand `accent`.** Do not rainbow a single series.
- **Categorical charts** (e.g. budget pie: fixed/discretionary/savings/investments) use a restrained
  ramp derived from `accent` + neutrals; cap distinct hues and keep them muted. No saturated
  primaries.
- **Gain/loss and variance** use `pos` (green) / `neg` (red) only — these carry financial meaning.
- **Heat map** (`HeatMapTableView`, 8 benchmark periods × N accounts) uses the `pos`/`neg` cell
  scale: green for positive % growth, red for negative, intensity by magnitude. The **S&P 500
  comparison row** is visually separated (top border, heavier weight) per the prototype `.sp500-row`.

## Typography & axes

- **All axis labels, tick values, tooltips, and data labels use tabular numerals** (`.monospacedDigit()`
  / `tabular-nums`). Money and percentages align or it reads as broken.
- Axis/label text is `muted`; gridlines are `border-soft`; the baseline axis is `border`.
- Format money and % consistently with the rest of the app (sign convention: negative = money out).

## Structure

- Respect the chart container sizes: **tall = 230px**, **short = 140px** (`.chart-wrap`).
- Charts are **traceable**: tapping a segment/bar navigates to the filtered detail (constitution #5).
- Provide an **empty state** when there's no data (no axes floating over a blank panel).
- Light **and** dark: verify the palette and gridlines have contrast in both modes (Swift Charts
  previews in both schemes; Chart.js reads the CSS variables).

## Checklist

- [ ] Colors via tokens; single accent for single series; pos/neg for gain/loss.
- [ ] Tabular numerals on every numeric label.
- [ ] Heat-map scale + S&P 500 row convention applied where relevant.
- [ ] Correct container height; empty state present; both color schemes verified.
