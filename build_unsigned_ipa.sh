#!/bin/bash

# Configuration
APP_NAME="streamsports"
SCHEME="streamsports"
PROJECT_DIR="ios/streamsports"
WEB_PUBLIC_DIR="web/public"
PLIST_PATH="$PROJECT_DIR/streamsports/Info.plist"
IPA_NAME="streamsports.ipa"
SIDESTORE_JSON="$WEB_PUBLIC_DIR/sidestore.json"
GITHUB_BASE_URL="https://raw.githubusercontent.com/akedidi/streamsports/main"

# 1. Get Version Info
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_PATH" 2>/dev/null || echo "1.0")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_PATH" 2>/dev/null || echo "1")
TODAY=$(date +%Y-%m-%d)

echo "🚀 Building $APP_NAME v$VERSION ($BUILD)..."

# 2. Build Archive
xcodebuild -workspace "$PROJECT_DIR/streamsports.xcworkspace" \
           -scheme "$SCHEME" \
           -configuration Release \
           -derivedDataPath "$PROJECT_DIR/build" \
           -destination 'generic/platform=iOS' \
           clean build \
           CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# 3. Create Unsigned IPA
echo "📦 Packaging IPA..."
APP_PATH=$(find "$PROJECT_DIR/build/Build/Products/Release-iphoneos" -name "*.app" | head -n 1)
mkdir -p Payload
cp -r "$APP_PATH" Payload/
zip -r "$IPA_NAME" Payload
rm -rf Payload
mv "$IPA_NAME" "$WEB_PUBLIC_DIR/$IPA_NAME"

IPA_SIZE=$(stat -f%z "$WEB_PUBLIC_DIR/$IPA_NAME")
echo "✅ IPA created at $WEB_PUBLIC_DIR/$IPA_NAME ($IPA_SIZE bytes)"

# 4. Update sidestore.json
echo "📝 Updating sidestore.json..."

# Description passed as argument or default
DESCRIPTION="${1:-Minor update and bug fixes}"

# JSON Update Logic (using node for reliability)
node -e "
const fs = require('fs');
const path = '$SIDESTORE_JSON';

// Default structure if file doesn't exist
let data = {
    name: '$APP_NAME',
    identifier: 'anis.com.$APP_NAME',
    sourceURL: '$GITHUB_BASE_URL/web/public/sidestore.json',
    apps: []
};

if (fs.existsSync(path)) {
    try {
        data = JSON.parse(fs.readFileSync(path, 'utf8'));
    } catch (e) {
        console.log('⚠️ Error reading existing JSON, starting fresh.');
    }
}

// Ensure apps array exists
if (!data.apps) data.apps = [];

// Prepare the App Object (Update static metadata every time)
const appMetadata = {
    name: 'StreamSports',
    bundleIdentifier: 'anis.com.streamsports',
    developerName: 'Anis Kedidi',
    localizedDescription: 'StreamSports est votre compagnon de streaming sportif ultime. Regardez vos événements préférés en direct.',
    iconURL: '$GITHUB_BASE_URL/web/public/icon.png',
};

// Find existing app or create new one
let app = data.apps.find(a => a.bundleIdentifier === appMetadata.bundleIdentifier);
if (!app) {
    app = { ...appMetadata, versions: [] };
    data.apps.push(app);
} else {
    // Update metadata fields
    Object.assign(app, appMetadata);
}

const newVersion = {
    version: '$VERSION',
    date: '$TODAY',
    size: $IPA_SIZE,
    downloadURL: '$GITHUB_BASE_URL/web/public/$IPA_NAME',
    minOSVersion: '16.0',
    localizedDescription: '$DESCRIPTION'
};

// Remove existing version entry if it exists (to update it)
if (app.versions) {
    app.versions = app.versions.filter(v => v.version !== '$VERSION');
} else {
    app.versions = [];
}

// Add new version to the TOP
app.versions.unshift(newVersion);

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log('✨ sidestore.json updated for version $VERSION');
"

echo "🎉 Done! Don't forget to push changes."
