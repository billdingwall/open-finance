#!/bin/bash
# package-release.sh — build, bundle, and package "Finance Workspace.app" for distribution from a
# single download link, entirely from the terminal (SwiftPM only — no Xcode GUI required).
#
#   Scripts/package-release.sh                 # unsigned (ad-hoc) zip + dmg in dist/
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="openfinance-notary" \
#   Scripts/package-release.sh                 # signed + notarized + stapled
#
# Distribution/storage strategy: this RELEASE bundle carries no iCloud entitlement, so at runtime
# the app selects `CloudDocsProvider` (the user's own iCloud Drive folder,
# ~/Library/Mobile Documents/com~apple~CloudDocs/OpenFinance) — see AppConfig.makeProvider().
# The app is therefore NOT sandboxed (the App Sandbox blocks Mobile Documents); the sandboxed +
# container-entitled build remains the Xcode target (App/project.yml).
#
# Contrast with Scripts/build-app.sh, which is the DEBUG dev launcher (local-folder provider).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.5.0}"
BUILD_NUM="${BUILD_NUM:-1}"
APP_NAME="Finance Workspace"
BUNDLE_ID="app.openfinance.FinanceWorkspace"
DIST="$REPO/dist"
APP="$DIST/$APP_NAME.app"
BIN="$REPO/.build/release/FinanceWorkspaceApp"
RES_BUNDLE="FinanceWorkspaceApp_FinanceWorkspaceKit.bundle"
ZIP="$DIST/FinanceWorkspace-$VERSION.zip"
DMG="$DIST/FinanceWorkspace-$VERSION.dmg"

# ── 1 · Compile ──────────────────────────────────────────────────────────────────────────────────
echo "→ swift build -c release …"
( cd "$REPO" && swift build -c release )

# ── 2 · Assemble the .app bundle ─────────────────────────────────────────────────────────────────
echo "→ assembling $APP …"
rm -rf "$APP" "$ZIP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/FinanceWorkspace"
# Bundle.module resolves the Kit's bundled resources (CSV schemas) from Contents/Resources.
cp -R "$REPO/.build/release/$RES_BUNDLE" "$APP/Contents/Resources/"
cp "$REPO/App/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>FinanceWorkspace</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleName</key><string>$APP_NAME</string>
	<key>CFBundleDisplayName</key><string>$APP_NAME</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD_NUM</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.finance</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSHumanReadableCopyright</key><string></string>
	<key>NSUserActivityTypes</key><array><string>app.openfinance.navigation</string></array>
</dict>
</plist>
PLIST

# Strip extended attributes — codesign rejects "resource fork / Finder detritus" otherwise.
xattr -cr "$APP"

# ── 3 · Sign ─────────────────────────────────────────────────────────────────────────────────────
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "→ codesign (Developer ID, hardened runtime) …"
  codesign --force --deep --options runtime --timestamp \
           --sign "$SIGN_IDENTITY" "$APP"
else
  echo "→ codesign (ad-hoc — Gatekeeper will warn; set SIGN_IDENTITY to sign for real) …"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --strict "$APP"

# ── 4 · Package: zip (primary download + notarization payload) and dmg ──────────────────────────
echo "→ packaging …"
# ditto with --keepParent produces the zip format notarytool expects.
ditto -c -k --keepParent "$APP" "$ZIP"

hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

# ── 5 · Notarize + staple (only when a keychain profile is configured) ───────────────────────────
if [[ -n "${SIGN_IDENTITY:-}" && -n "${NOTARY_PROFILE:-}" ]]; then
  echo "→ notarytool submit (waits for Apple's verdict) …"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

  echo "→ stapling tickets …"
  xcrun stapler staple "$APP"
  xcrun stapler staple "$DMG"
  # Re-zip so the downloadable zip contains the STAPLED app.
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"

  echo "→ Gatekeeper assessment:"
  spctl --assess --type execute --verbose=2 "$APP"
fi

echo ""
echo "✓ Done."
echo "   app: $APP"
echo "   zip: $ZIP   ← upload this (or the dmg) as the download link"
echo "   dmg: $DMG"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  cat <<'CHECKLIST'

⚠ UNSIGNED build — on another Mac, Gatekeeper will block first launch (right-click → Open works).
To distribute smoothly, sign + notarize (one-time setup, then re-run this script):

  1. Join the Apple Developer Program ($99/yr) — required for Developer ID certificates.
  2. Create a "Developer ID Application" certificate (developer.apple.com → Certificates, or
     Xcode → Settings → Accounts → Manage Certificates) and install it in your login keychain.
     Verify:   security find-identity -v -p codesigning
  3. Create an App Store Connect API key (or app-specific password) and store it once:
       xcrun notarytool store-credentials openfinance-notary \
         --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
  4. Re-run:
       SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
       NOTARY_PROFILE="openfinance-notary" Scripts/package-release.sh
     The script signs with the hardened runtime + secure timestamp, submits the zip to Apple
     (notarytool --wait), staples the ticket to the .app and .dmg, and re-zips the stapled app.
  5. Upload the zip or dmg anywhere (S3, GitHub Releases, your site). Downloaders can launch it
     with no Gatekeeper prompt — the stapled ticket verifies offline.
CHECKLIST
fi
