#!/bin/bash
set -e

# -----------------------------
# CONFIGURATION
# -----------------------------
TELEGRAM_DIR="$HOME/Documents/GitHub/Tongram AI"  # path to your Tongram AI repo
BAZEL_CACHE="$HOME/telegram-bazel-cache"
CONFIG_JSON="build-system/template_minimal_development_configuration.json"
# Set your iOS SDK version here (check with xcodebuild -showsdks)
IOS_SDK_VERSION="15.6"
BAZEL_VERSION="8.4.0"

# -----------------------------
# 1. Quit Xcode
# -----------------------------
echo "Quitting Xcode..."
killall Xcode || true

# -----------------------------
# 2. Delete Telegram DerivedData
# -----------------------------
echo "Deleting Telegram DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Telegram-*

echo "Deleting Bazel Cache..."
rm -rf ~/telegram-bazel-cache

echo "Set Bazel version $BAZEL_VERSION"
echo "$BAZEL_VERSION" > .bazelversion
# -----------------------------
# 3. Fix SDK version in JSON
# -----------------------------
echo "Updating iOS SDK version in configuration..."
CONFIG_PATH="$TELEGRAM_DIR/$CONFIG_JSON"
if [ -f "$CONFIG_PATH" ]; then
  # Backup original
  cp "$CONFIG_PATH" "$CONFIG_PATH.bak"
  # Replace ios_sdk_version
  sed -i '' "s/\"ios_sdk_version\": \".*\"/\"ios_sdk_version\": \"$IOS_SDK_VERSION\"/" "$CONFIG_PATH"
else
  echo "ERROR: Configuration JSON not found at $CONFIG_PATH"
  exit 1
fi

# sudo chown -R $USER:$USER ~/Library/Developer/Xcode/DerivedData
# \sudo chmod -R u+w ~/Library/Developer/Xcode/DerivedData

# -----------------------------
# 4. Regenerate Xcode project
# -----------------------------
echo "Regenerating Xcode project..."
cd "$TELEGRAM_DIR"
python3 build-system/Make/Make.py \
    --bazel=$(which bazelisk) \
    --overrideXcodeVersion \
    --cacheDir="$BAZEL_CACHE" \
    generateProject \
    --configurationPath="$CONFIG_JSON" \
    --xcodeManagedCodesigning
    
# --disableProvisioningProfiles \
# -----------------------------
# 5. Open Xcode project
# -----------------------------
echo "Opening Xcode project. WAIT until indexing finishes to generate PIFCache..."
#open "$TELEGRAM_DIR/Telegram.xcodeproj"

# -----------------------------
# 6. Instructions for Archiving
# -----------------------------
echo ""
echo "✅ Xcode project opened. Please follow these steps:"
echo "1. Wait until Xcode finishes indexing (status bar must be idle)."
echo "2. Go to Product → Scheme → Edit Scheme → Archive → set Build Configuration to Release."
echo "3. Clean Build Folder: Shift+Command+K"
echo "4. Archive: Product → Archive"
echo ""
