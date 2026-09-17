#!/bin/bash
set -e

APP_NAME="AutoMacro"
BUNDLE_ID="com.user.AutoMacro"
BUILD_DIR=".build/debug"
INSTALL_DIR="/Applications"
APP_BUNDLE="${INSTALL_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
DMG_NAME="${APP_NAME}.dmg"
ICON_SOURCE="Icon.jpeg"

# ─── Build ────────────────────────────────────────────────────────
echo "📦 Building ${APP_NAME}..."
swift build -c debug 2>&1

# ─── App Icon (.icns) ─────────────────────────────────────────────
ICNS_FILE=""
if [ -f "${ICON_SOURCE}" ]; then
    echo "🎨 Generating app icon from ${ICON_SOURCE}..."
    ICONSET_DIR="${APP_NAME}.iconset"
    rm -rf "${ICONSET_DIR}"
    mkdir -p "${ICONSET_DIR}"

    # Generate the full standard iconset. iconutil needs the small sizes too —
    # without 16/32px the .icns has no Finder list-view or menu-bar variant.
    for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
                "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" \
                "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
        SIZE="${spec%% *}"
        NAME="${spec##* }"
        sips -s format png -z "$SIZE" "$SIZE" "${ICON_SOURCE}" --out "${ICONSET_DIR}/${NAME}.png" > /dev/null 2>&1
    done

    # Convert iconset to .icns
    iconutil -c icns "${ICONSET_DIR}" -o "AppIcon.icns" 2>/dev/null && ICNS_FILE="AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
fi

# ─── Assemble .app Bundle ─────────────────────────────────────────
echo "🗂  Installing to ${INSTALL_DIR}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"
chmod +x "${MACOS}/${APP_NAME}"

# Copy icon if generated
if [ -n "${ICNS_FILE}" ] && [ -f "${ICNS_FILE}" ]; then
    cp "${ICNS_FILE}" "${RESOURCES}/AppIcon.icns"
fi

# Write Info.plist
cat > "${CONTENTS}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}+</string>
    <key>CFBundleDisplayName</key>
    <string>AutoMacro+</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSHumanReadableShortDescription</key>
    <string>Macro auto-clicker and keyboard automation</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>AutoMacro+ needs Accessibility access to simulate mouse clicks and keyboard presses for macro automation.</string>
</dict>
</plist>
EOF

# ─── Code Sign ────────────────────────────────────────────────────
echo "🔏 Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || echo "   (codesign skipped)"

echo ""
echo "✅ Installed to: ${APP_BUNDLE}"

# ─── Create .dmg ──────────────────────────────────────────────────
echo ""
echo "💿 Creating ${DMG_NAME}..."

# Clean up any existing DMG or temp directory
rm -f "${DMG_NAME}"
DMG_STAGING="dmg_staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"

# Copy the .app into staging
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"

# Add a symlink to /Applications for drag-to-install
ln -s /Applications "${DMG_STAGING}/Applications"

# Create the DMG
hdiutil create \
    -volname "AutoMacro+" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}" > /dev/null 2>&1

# Clean up staging
rm -rf "${DMG_STAGING}"

echo "✅ DMG created: ${DMG_NAME}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 ${DMG_NAME}  — distribute this file!"
echo "  📂 ${APP_BUNDLE} — installed locally"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔑 First launch: grant Accessibility in System Settings"
