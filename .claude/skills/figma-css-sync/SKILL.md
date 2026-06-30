---
name: "figma-css-sync"
description: "Keep Figma design variables, the DESIGN.md token layer, and prototype/styles.css in agreement using figma-cli (CDP bridge to Figma Desktop) and the figma-console MCP. Use to pull design tokens/icons from Figma into the repo, or to push the system's tokens into Figma, and to reconcile drift between Figma and code."
metadata:
  author: "open-finance"
  inspired-by: "google-labs-code/design.md"
user-invocable: true
disable-model-invocation: false
---

# Figma ↔ CSS Sync (figma-cli)

Bridge the design source (Figma Desktop) and the code token sources so the brand never forks between
the design file and the build. Uses **figma-cli** (local CLI over CDP — no API key) and the
**figma-console MCP** (`figma_*` tools) for live reads/writes.

## What stays in sync

- **Figma variables/styles** (colors, typography, radius, spacing) in the Open Finance design file.
- **`DESIGN.md` front matter** — the semantic token contract.
- **`prototype/styles.css` `:root`** — the rendered CSS variables.
- **Exports**: design tokens → `docs/_design/tokens/` (DTCG/W3C JSON); icons/SVG → `docs/_design/icons/`.

`DESIGN.md` + `styles.css` remain the source of truth for the **build**; Figma is the source of truth
for **exploration and visual review**. Sync moves intent between them deliberately, not silently.

## Setup check

1. Confirm Figma Desktop is open with the Open Finance file. Re-resolve node IDs every session
   (`figma_search_components` / `figma_list_open_files`) — IDs are session-specific and go stale.
2. Confirm figma-cli is installed (Yolo mode, per `CLAUDE.md`). If not, install it before proceeding.

## Pull (Figma → repo)

1. Read variables/styles via the MCP (`figma_get_variables`, `figma_get_styles`,
   `figma_get_text_styles`) or `figma_export_tokens`.
2. Normalize to the **semantic token names** in `DESIGN.md` (not Figma's literal layer names). Map
   light/dark modes to the front-matter `light`/`dark` fields.
3. Write the DTCG export to `docs/_design/tokens/` and any new icons to `docs/_design/icons/`.
4. Hand the value diff to `design-token-sync` to update `DESIGN.md` front matter and `styles.css`.

## Push (repo → Figma)

1. From `DESIGN.md` front matter, build the variable set (collections per mode: light/dark).
2. Apply via `figma_batch_create_variables` / `figma_batch_update_variables`.
3. **Screenshot to verify** (`figma_take_screenshot`) — per the figma-console workflow, always
   visually confirm after writing; iterate up to 3 times.

## Reconcile (drift audit)

1. Diff Figma values against `DESIGN.md` front matter, keyed by semantic token.
2. Report drift in three buckets: value, missing-in-one, naming. Choose a direction explicitly
   (pull vs push) — never auto-overwrite the brand.
3. Apply, then re-verify with a screenshot and a `design-token-sync` clean check.

## Rules

- Always map to **semantic** token names; never let Figma's raw layer names leak into code.
- Every token carries light **and** dark; flag any Figma variable missing a mode.
- Run `design-adherence` if a sync would change the visual language, not just values.
- Keep `docs/_design/tokens/` (DTCG) and `docs/_design/icons/` as the committed export targets.
