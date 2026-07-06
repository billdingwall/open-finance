# Contract: Accessibility & Native Behavior (US5)

## Accessibility (FR-018/019)

- **Keyboard**: every interactive element reachable/operable by keyboard alone; focus order
  sidebar → main → inspector; arrows/Return/Escape in tables and the detail pane. (Audit + fill gaps.)
- **VoiceOver**: descriptive `.accessibilityLabel` on every interactive element (extend existing usage).
- **Contrast**: all text/status/chart colors meet **WCAG AA** in light + dark. Audit every
  `DesignSystem` token; any failure is fixed via `design-token-sync` (not a one-off view override).

## Window restoration (FR-020)

**`NSUserActivity` (codec exists, unit-tested — OOS-9)**

- Relaunch restores the prior module + selection; when the prior entity no longer exists, restore to
  the nearest valid context (never an error). **Verify end-to-end in the signed app** (the SwiftPM
  executable can't register `NSUserActivityTypes` at runtime).

## Menu + drag-drop (FR-021)

- The full documented macOS command set is present, each enabled only when applicable — including
  **Open Backup Folder**. (Verify against the §17 `CommandMatrix`.)
- Register `.csv`/`.md` `UTType` **drag-and-drop** onto the app → offers the matching import/behavior.

## Onboarding (FR-022)

**Require-iCloud first launch (clarify Q5 — no local store in v1)**

- Guide workspace creation; when iCloud is **unavailable**, present a clear **"enable iCloud"** state
  with a **retry** (block creation; no local-folder fallback), then proceed once iCloud is available.
- On success: confirm + prompt "add your first account".

**Guarantees**: full keyboard + VoiceOver + WCAG AA; restoration works in the signed build; onboarding
never dead-ends and never creates a local store.
