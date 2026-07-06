# Contract: Packaging & Sync (US3)

## Code signing + notarization (FR-010 · OOS-1)

**`App/project.yml` (XcodeGen app target)**

- Signing: **Developer ID Application**, hardened runtime enabled.
- Entitlement: `iCloud.<bundle-id>` ubiquity container (already attached in Phase 5).
- Release step (developer machine): `xcodegen generate` → build → `notarytool submit --wait` →
  `stapler staple`. No Mac App Store / TestFlight this phase.
- CI unchanged: builds **unsigned** (`CODE_SIGNING_ALLOWED=NO`) on the macOS runner.

**Guarantees**: a signed, notarized `.app` launches on a real device and resolves the iCloud container
with no entitlement/signing error.

## iCloud sync + per-file state (FR-011)

**`ICloudContainerService` (reused)**

- Per-file sync state from `NSMetadataQuery` surfaces in the header sync chip + per-row badges
  throughout (existing).
- An edit saved on device A propagates to device B after sync; state is shown throughout.
- **Verification is manual** on a signed build across two Macs on one Apple ID (not CI-runnable).

## Conflict resolution (FR-012 · P-IV)

**Conflict surface ⇄ `NSFileVersion`**

- When a file enters the `conflict` sync state, surface a **"conflict detected"** state and a
  resolution view listing the `NSFileVersion` alternatives (current + others).
- User makes an **explicit choice** — keep-mine / keep-iCloud — then resolve via
  `NSFileVersion.removeOtherVersions`; re-index after. **No auto-merge, no latest-wins.**
- Writes to a conflicted file remain blocked by the existing `WriteGate` sync gate until resolved.

**Guarantees**: no silent data loss; resolution is always a user decision (constitution P-IV).
