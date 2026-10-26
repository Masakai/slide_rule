#!/bin/bash
# macOS 版 SlideRule.app を Developer ID で署名し、公証・staple して、配布用の zip にする。
# 使い方: Tools/notarize_mac.sh [版番号]      例: Tools/notarize_mac.sh 0.1.0
#
# 必要なもの（どちらも Local.xcconfig に書く。git 管理外）
#   DEVELOPMENT_TEAM    チーム ID
#   MAC_SIGN_IDENTITY   Developer ID Application 証明書の SHA-1 ハッシュ
#                       （同じ名前の証明書が複数あるときに取り違えないよう、ハッシュで指定する）
# 公証は Keychain のプロファイル "notarytool-password" を使う（NOTARY_PROFILE で変更可）。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(grep -E '^ +MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')}"
KEYCHAIN_PROFILE="${NOTARY_PROFILE:-notarytool-password}"

read_local() {
    grep -E "^[[:space:]]*$1[[:space:]]*=" Local.xcconfig 2>/dev/null | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//'
}
TEAM="$(read_local DEVELOPMENT_TEAM)"
SIGN_IDENTITY="$(read_local MAC_SIGN_IDENTITY)"
[ -n "$TEAM" ] || { echo "Error: Local.xcconfig に DEVELOPMENT_TEAM がありません"; exit 1; }
[ -n "$SIGN_IDENTITY" ] || { echo "Error: Local.xcconfig に MAC_SIGN_IDENTITY がありません"; exit 1; }

# DerivedData は Dropbox の同期対象にしない
BUILD_DIR="${TMPDIR:-/tmp}/SlideRule-mac-release"
APP="dist/SlideRule.app"
NOTARIZE_ZIP="dist/SlideRule-notarize.zip"
FINAL_ZIP="dist/SlideRule-${VERSION}-mac.zip"

echo "==> Generating project..."
xcodegen generate --quiet

echo "==> Building SlideRule.app ${VERSION} (Release, universal, Developer ID)..."
rm -rf "$BUILD_DIR"
xcodebuild -project SlideRule.xcodeproj -scheme SlideRule -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" \
    MARKETING_VERSION="$VERSION" \
    DEVELOPMENT_TEAM="$TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    -quiet build

mkdir -p dist
rm -rf "$APP"
ditto "$BUILD_DIR/Build/Products/Release/SlideRule.app" "$APP"

echo "==> Verifying..."
codesign --verify --deep --strict --verbose=2 "$APP"
archs="$(lipo -archs "$APP/Contents/MacOS/SlideRule" | tr ' ' '\n' | sort | xargs)"
[ "$archs" = "arm64 x86_64" ] || { echo "Error: architectures [$archs], expected [arm64 x86_64]"; exit 1; }
entitlements="$(codesign --display --entitlements - --xml "$APP" 2>/dev/null | plutil -p - 2>/dev/null || true)"
if echo "$entitlements" | grep -q "get-task-allow"; then
    echo "Error: get-task-allow が含まれています（公証に失敗します）"; exit 1
fi
if ! echo "$entitlements" | grep -q '"com.apple.security.app-sandbox" => true'; then
    echo "Error: App Sandbox が有効になっていません"; exit 1
fi
codesign -dvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier|flags|Timestamp"

echo "==> Submitting to the Apple notary service..."
rm -f "$NOTARIZE_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARIZE_ZIP"
xcrun notarytool submit "$NOTARIZE_ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait
rm -f "$NOTARIZE_ZIP"

echo "==> Stapling..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> syspolicy_check..."
syspolicy_check distribution "$APP" || { echo "Error: syspolicy_check に失敗しました。配布しないでください"; exit 1; }

rm -f "$FINAL_ZIP"
ditto -c -k --keepParent "$APP" "$FINAL_ZIP"
echo "==> Done: $FINAL_ZIP"
