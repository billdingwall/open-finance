#!/bin/bash
# Build "Finance Workspace.app" — a double-clickable macOS app bundle wrapping the SwiftPM
# executable, for LOCAL DEV on a Command-Line-Tools-only machine (no full Xcode / xcodebuild).
#
# This is a convenience launcher: it's the DEBUG build (local-folder provider, reads
# ~/Finance-Dev/Finance), ad-hoc signed, with the generic app icon. The real signed/notarized
# app with iCloud + a designed icon is built from the Xcode target (App/project.yml) in CI /
# Phase 7. Re-run this after any code change to refresh the bundle. Output is gitignored.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$REPO/Finance Workspace.app"
BIN="$REPO/.build/debug/FinanceWorkspaceApp"
RES_BUNDLE="FinanceWorkspaceApp_FinanceWorkspaceKit.bundle"

echo "→ swift build (debug)…"
( cd "$REPO" && swift build )

echo "→ assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FinanceWorkspace"
# Bundle.module resolves the Kit's resource bundle from Contents/Resources.
cp -R "$REPO/.build/debug/$RES_BUNDLE" "$APP/Contents/Resources/"
# App icon (regenerate with scripts/make-icon.swift).
cp "$REPO/App/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>FinanceWorkspace</string>
	<key>CFBundleIdentifier</key><string>app.openfinance.FinanceWorkspace.dev</string>
	<key>CFBundleName</key><string>Finance Workspace</string>
	<key>CFBundleDisplayName</key><string>Finance Workspace</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleShortVersionString</key><string>0.5.0-dev</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSUserActivityTypes</key><array><string>app.openfinance.navigation</string></array>
</dict>
</plist>
PLIST

# Strip xattrs (else codesign rejects "resource fork / detritus") and ad-hoc sign so it launches.
xattr -cr "$APP"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
codesign --verify "$APP"

echo "✓ Built: $APP"
echo "  Double-click it in Finder, or: open \"$APP\""
