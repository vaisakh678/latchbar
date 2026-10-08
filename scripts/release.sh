#!/usr/bin/env bash
# Builds a Developer ID–signed, notarized Latchbar.app, zips it, then publishes it
# as a GitHub Release and updates the Homebrew cask in vaisakh678/homebrew-tap.
#
# Usage: scripts/release.sh <version> [--yes | --no-publish]
#   --yes         publish without asking for confirmation
#   --no-publish  only build, sign, notarize and zip
#
# Release from an up-to-date, pushed development branch: the GitHub Release tags
# the current commit.
#
# One-time setup:
#   - A "Developer ID Application" certificate for team KTJUU8D53Q in the keychain.
#   - Notary credentials saved in the keychain:
#       xcrun notarytool store-credentials emudock-notary \
#         --key <AuthKey.p8> --key-id <KEY_ID> --issuer <ISSUER_ID>
#     (the profile is per team, so the one made for EmuDock works here too;
#     set NOTARY_PROFILE to use a different one)
#   - The GitHub CLI logged in with push access to both repos (gh auth login).
set -euo pipefail

VERSION=${1:?usage: scripts/release.sh <version, e.g. 0.1.0> [--yes | --no-publish]}
MODE=${2:-}
TEAM_ID=KTJUU8D53Q
NOTARY_PROFILE=${NOTARY_PROFILE:-emudock-notary}
REPO=vaisakh678/latchbar
TAP_REPO=vaisakh678/homebrew-tap
CASK=Casks/latchbar.rb
TAG=v$VERSION

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/build/release/$VERSION
# Build numbers must increase between releases; the commit count does.
BUILD=$(git -C "$ROOT" rev-list --count HEAD)

step() { printf '\n==> %s\n' "$*"; }

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($TEAM_ID)"; then
    echo "No 'Developer ID Application' certificate for team $TEAM_ID in the keychain." >&2
    echo "Create one in Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application." >&2
    exit 1
fi

case $MODE in
    "" | --yes | --no-publish) ;;
    *) echo "Unknown option: $MODE" >&2; exit 1 ;;
esac

# Check what publishing needs before the long build.
if [[ $MODE != --no-publish ]]; then
    gh auth status >/dev/null 2>&1 || { echo "Not logged in to GitHub. Run: gh auth login" >&2; exit 1; }
    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
        echo "Release $TAG already exists on $REPO." >&2
        exit 1
    fi
    if [[ -n $(git -C "$ROOT" status --porcelain) ]]; then
        echo "The working tree has uncommitted changes. Commit or stash them first." >&2
        exit 1
    fi
    COMMIT=$(git -C "$ROOT" rev-parse HEAD)
    git -C "$ROOT" fetch --quiet origin
    if [[ -z $(git -C "$ROOT" branch -r --contains "$COMMIT") ]]; then
        echo "Commit ${COMMIT:0:7} isn't pushed to GitHub yet. Push it first." >&2
        exit 1
    fi
fi

rm -rf "$OUT"
mkdir -p "$OUT"

step "Generating Xcode project"
(cd "$ROOT" && xcodegen generate --quiet)

step "Archiving Latchbar $VERSION ($BUILD)"
xcodebuild -project "$ROOT/Latchbar.xcodeproj" -scheme Latchbar -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$OUT/Latchbar.xcarchive" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
    archive -quiet

step "Exporting with Developer ID signing"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$OUT/Latchbar.xcarchive" -exportPath "$OUT/export" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -quiet
APP=$OUT/export/Latchbar.app
codesign --verify --deep --strict --verbose=2 "$APP"

step "Notarizing (usually a few minutes)"
ditto -c -k --keepParent "$APP" "$OUT/Latchbar-notarize.zip"
xcrun notarytool submit "$OUT/Latchbar-notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
rm "$OUT/Latchbar-notarize.zip"

step "Stapling the notarization ticket"
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"

step "Packaging"
ZIP=$OUT/Latchbar-$VERSION.zip
ditto -c -k --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

printf '\nBuilt.\n  %s\n  sha256 %s\n' "$ZIP" "$SHA"

[[ $MODE == --no-publish ]] && exit 0

if [[ $MODE != --yes ]]; then
    read -r -p $'\nPublish '"$TAG"' to GitHub and Homebrew? [y/N] ' answer
    [[ $answer == [yY]* ]] || { echo "Not published."; exit 0; }
fi

step "Creating GitHub Release $TAG"
gh release create "$TAG" "$ZIP" --repo "$REPO" --target "$COMMIT" \
    --title "Latchbar $VERSION" --generate-notes

step "Updating the Homebrew cask"
TAP=$OUT/homebrew-tap
gh repo clone "$TAP_REPO" "$TAP" -- --quiet
if [[ ! -f $TAP/$CASK ]]; then
    cp "$ROOT/scripts/latchbar.rb" "$TAP/$CASK"
fi
sed -i '' -E \
    -e "s/^  version \".*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" \
    "$TAP/$CASK"
git -C "$TAP" add "$CASK"
git -C "$TAP" commit --quiet -m "Update Latchbar to $VERSION"
# Push with the GitHub CLI's account, not whatever git has saved in the keychain.
git -C "$TAP" -c credential.helper= -c credential.helper='!gh auth git-credential' push --quiet
rm -rf "$TAP"

printf '\nPublished Latchbar %s.\n  https://github.com/%s/releases/tag/%s\n  brew upgrade --cask latchbar\n' \
    "$VERSION" "$REPO" "$TAG"
