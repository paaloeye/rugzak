#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  create_dmg.sh
#
# Build and create DMG distribution:
#
# 1. Builds in Release configuration
# 2. Creates a distributable DMG with app and Applications folder link
# 3. Optionally code signs and notarizes the DMG
#

set -euo pipefail

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# Parse arguments
SCHEME=""
PROJECT=""
CLEAN=false
SIGN=false
DEV_SIGN=false
NOTARIZE=false
VERBOSE=false
SIGNING_IDENTITY=""
TEAM_ID=""
APPLE_ID=""
NOTARIZE_PASSWORD=""
KEYCHAIN_PROFILE=""
API_KEY_PATH=""
API_KEY_ID=""
API_ISSUER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --dev-sign)
            DEV_SIGN=true
            SIGNING_IDENTITY="Apple Development"
            shift
            ;;
        --sign)
            SIGN=true
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --notarize)
            NOTARIZE=true
            TEAM_ID="$2"
            shift 2
            ;;
        --apple-id)
            APPLE_ID="$2"
            shift 2
            ;;
        --password)
            NOTARIZE_PASSWORD="$2"
            shift 2
            ;;
        --keychain-profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        --api-key)
            API_KEY_PATH="$2"
            shift 2
            ;;
        --api-key-id)
            API_KEY_ID="$2"
            shift 2
            ;;
        --api-issuer)
            API_ISSUER="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;

        --help|-h)
            echo "Usage: $0 SCHEME [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  SCHEME                     Xcode scheme to build (required)"
            echo ""
            echo "Options:"
            echo "  --project PROJECT          Xcode project name (default: same as SCHEME)"
            echo "  --clean                    Clean build (remove derived data)"
            echo "  --dev-sign                 Sign with Apple Development"
            echo "  --sign IDENTITY            Code sign with specified identity (e.g., 'Developer ID Application')"
            echo "  --notarize TEAM_ID         Notarize DMG (requires --sign)"
            echo "  --keychain-profile NAME    Keychain profile for notarytool (local dev)"
            echo "  --apple-id EMAIL           Apple ID for notarization"
            echo "  --password PASS            App-specific password (use @keychain:NAME to read from Keychain)"
            echo "  --api-key PATH             Path to App Store Connect API key .p8 file (CI preferred)"
            echo "  --api-key-id ID            App Store Connect API key ID"
            echo "  --api-issuer ID            App Store Connect issuer ID"
            echo "  --verbose,-v               Show detailed build output"
            echo "  --help,-h                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 SCHEME                                           # Basic DMG creation (unsigned)"
            echo "  $0 SCHEME --dev-sign                                # Development signed"
            echo "  $0 SCHEME --sign \"Developer ID Application: Name\" # Distribution signed DMG"
            echo "  $0 SCHEME --sign \"Developer ID Application: Name\" --notarize TEAM_ID --keychain-profile AC_PASSWORD"
            echo "  $0 SCHEME --sign \"Developer ID Application: Name\" --notarize TEAM_ID --apple-id you@example.com --password @keychain:AC_PASSWORD"
            echo ""
            echo "Store credentials in Keychain (one-time setup):"
            echo "  xcrun notarytool store-credentials AC_PASSWORD --apple-id you@example.com --team-id TEAM_ID"
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;

        *)
            if [[ -z "$SCHEME" ]]; then
                SCHEME="$1"
            else
                echo -e "${RED}Error: Unexpected argument '$1'${NC}"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;

    esac
done

if [[ -z "$SCHEME" ]]; then
    echo -e "${RED}Error: SCHEME is required${NC}"
    echo "Use --help for usage information"
    exit 1
fi

PROJECT="${PROJECT:-$SCHEME}"

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_ROOT}/${PROJECT}.xcodeproj"
BUILD_CONFIG="Release"
DERIVED_DATA="${PROJECT_ROOT}/.tmp/DerivedData"
DIST_DIR="${PROJECT_ROOT}/.tmp/dist"
DMG_DIR="${PROJECT_ROOT}/.dist"

echo "=================================================="
echo "  ${SCHEME} DMG Creator"
echo "=================================================="
echo ""

# Create output directories
mkdir -p "${DIST_DIR}"
mkdir -p "${DMG_DIR}"

# Determine grep filter for build output
if [ "$VERBOSE" = true ]; then
    GREP_FILTER="cat"
else
    GREP_FILTER="grep -E '(error:|warning:|Build Succeeded|Build Failed|\*\* BUILD)' || true"
fi

cd "${PROJECT_ROOT}"

echo -e "${YELLOW}Building ${SCHEME} (${BUILD_CONFIG})...${NC}"

if [ "$SIGN" = true ]; then
    echo "  Code signing with: ${SIGNING_IDENTITY}"
    echo ""
    echo -e "${BLUE}Available signing identities:${NC}"
    security find-identity -v -p codesigning
    echo ""
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -destination "generic/platform=macOS" \
        build \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
        OTHER_CODE_SIGN_FLAGS="--timestamp" \
        | eval "$GREP_FILTER"
elif [ "$DEV_SIGN" = true ]; then
    echo "  Code signing: automatic (Apple Development)"
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -destination "generic/platform=macOS" \
        build \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_STYLE=Automatic \
        | eval "$GREP_FILTER"
else
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${SCHEME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -destination "generic/platform=macOS" \
        build \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        | eval "$GREP_FILTER"
fi

BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -ne 0 ]; then
    echo -e "${RED}✗ ${SCHEME} build failed${NC}"
    echo ""
    echo -e "${YELLOW}Available signing identities:${NC}"
    security find-identity -v -p codesigning
    exit 1
fi

APP_PATH="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/${SCHEME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}✗ ${SCHEME}.app not found in ${APP_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${SCHEME}.app built successfully${NC}"
echo ""

# Extract version information
VERSION=$(defaults read "${APP_PATH}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
BUILD=$(defaults read "${APP_PATH}/Contents/Info.plist" CFBundleVersion 2>/dev/null)
GIT_COMMIT_FROM_PLIST=$(defaults read "${APP_PATH}/Contents/Info.plist" GitCommitHash 2>/dev/null || echo "unknown")
GIT_BUILD_STATUS_FROM_PLIST=$(defaults read "${APP_PATH}/Contents/Info.plist" GitBuildStatus 2>/dev/null || echo "unknown")

echo -e "${BLUE}Version Information:${NC}"
echo "  Version: ${VERSION}"
echo "  Build: ${BUILD}"
echo "  Git commit: ${GIT_COMMIT_FROM_PLIST}"
echo "  Git build status: ${GIT_BUILD_STATUS_FROM_PLIST}"
echo ""

# Build DMG name with git information
DMG_NAME="${SCHEME}-${VERSION}-${GIT_COMMIT_FROM_PLIST}"
if [ "${GIT_BUILD_STATUS_FROM_PLIST}" = "dirty" ]; then
    DMG_NAME="${DMG_NAME}-dirty"
fi

TEMP_DMG="${DIST_DIR}/${DMG_NAME}-temp.dmg"
FINAL_DMG="${DMG_DIR}/${DMG_NAME}.dmg"

# Create staging directory for DMG contents
STAGING_DIR="${DIST_DIR}/staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy app to staging directory
echo -e "${YELLOW}Preparing DMG contents...${NC}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"

# Create symbolic link to Applications folder
ln -s /Applications "${STAGING_DIR}/Applications"

echo -e "${GREEN}✓ DMG contents prepared${NC}"
echo ""

# Create DMG
echo -e "${YELLOW}Creating DMG image...${NC}"

# Remove old DMG files if they exist
rm -f "${TEMP_DMG}"
rm -f "${FINAL_DMG}"

# Create temporary DMG
hdiutil create \
    -volname "${SCHEME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    "${TEMP_DMG}"

# Mount via standard DiskArbitration (lets Finder see the disk; no custom mountpoint, no root needed)
MOUNT_DIR=$(hdiutil attach "${TEMP_DMG}" | awk '/\/Volumes\// {print $NF}')

# Wait until Finder has registered the disk, then set icon layout — single session avoids inter-call races
osascript <<EOF || true
tell application "Finder"
    -- -- wait is probably optional but might be handy in CI
    -- set waited to 0
    -- repeat
    --     try
    --         set d to disk "${SCHEME}"
    --         exit repeat
    --     on error
    --         delay 0.5
    --         set waited to waited + 0.5
    --         if waited > 30 then error "Timed out waiting for disk '${SCHEME}' to appear in Finder"
    --     end try
    -- end repeat
    tell disk "${SCHEME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "${SCHEME}.app" of container window to {125, 225}
        set position of item "Applications" of container window to {375, 225}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Unmount the DMG
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed read-only DMG
echo -e "${YELLOW}Compressing DMG...${NC}"
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -o "${FINAL_DMG}"

# Clean up
rm -f "${TEMP_DMG}"
rm -rf "${STAGING_DIR}"

echo -e "${GREEN}✓ DMG created${NC}"
echo ""

# Code sign DMG if requested (skip for dev-sign)
if [ "$SIGN" = true ]; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    codesign --sign "${SIGNING_IDENTITY}" \
        --force \
        --timestamp \
        "${FINAL_DMG}"
    echo -e "${GREEN}✓ DMG signed${NC}"
elif [ "$DEV_SIGN" = true ]; then
    echo -e "${BLUE}Skipping DMG signing for development build${NC}"
    echo ""
fi

# Notarize if requested
if [ "$NOTARIZE" = true ]; then
    if [ "$SIGN" != true ]; then
        echo -e "${RED}Error: --notarize requires --sign${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Submitting DMG for notarization...${NC}"
    echo "  (This may take several minutes)"

    NOTARIZE_AUTH_ARGS=()
    if [ -n "${API_KEY_PATH}" ] && [ -n "${API_KEY_ID}" ] && [ -n "${API_ISSUER}" ]; then
        echo "  Auth:     App Store Connect API key"
        echo "  Key ID:   ${API_KEY_ID}"
        echo "  Issuer:   ${API_ISSUER}"
        echo "  Key path: ${API_KEY_PATH}"
        if [ ! -f "${API_KEY_PATH}" ]; then
            echo -e "${RED}✗ API key file not found: ${API_KEY_PATH}${NC}"
            exit 1
        fi
        NOTARIZE_AUTH_ARGS=(--key "${API_KEY_PATH}" --key-id "${API_KEY_ID}" --issuer "${API_ISSUER}")
    elif [ -n "${KEYCHAIN_PROFILE}" ]; then
        NOTARIZE_AUTH_ARGS=(--keychain-profile "${KEYCHAIN_PROFILE}")
    elif [ -n "${APPLE_ID}" ] && [ -n "${NOTARIZE_PASSWORD}" ]; then
        NOTARIZE_AUTH_ARGS=(--apple-id "${APPLE_ID}" --password "${NOTARIZE_PASSWORD}" --team-id "${TEAM_ID}")
    else
        echo -e "${RED}Error: notarization requires one of:${NC}"
        echo "  --api-key PATH --api-key-id ID --api-issuer ID   (CI / App Store Connect API key)"
        echo "  --keychain-profile NAME                          (local dev)"
        echo "  --apple-id EMAIL --password PASS                 (app-specific password)"
        exit 1
    fi

    SUBMIT_OUTPUT=$(xcrun notarytool submit "${FINAL_DMG}" \
        "${NOTARIZE_AUTH_ARGS[@]}" 2>&1) || true
    echo "${SUBMIT_OUTPUT}"

    SUBMISSION_ID=$(echo "${SUBMIT_OUTPUT}" | grep "  id:" | head -1 | awk '{print $2}')

    if [ -z "${SUBMISSION_ID}" ]; then
        echo -e "${RED}✗ Failed to obtain submission ID — upload may have failed${NC}"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}Submission ID: ${SUBMISSION_ID}${NC}"
    echo "  Monitor:  xcrun notarytool info     ${NOTARIZE_AUTH_ARGS[*]} ${SUBMISSION_ID}"
    echo "  Log:      xcrun notarytool log      ${NOTARIZE_AUTH_ARGS[*]} ${SUBMISSION_ID}"
    echo "  History:  xcrun notarytool history  ${NOTARIZE_AUTH_ARGS[*]}"
    echo ""
    echo -e "${YELLOW}Waiting for Apple notarization service...${NC}"

    WAIT_OUTPUT=$(xcrun notarytool wait "${SUBMISSION_ID}" \
        "${NOTARIZE_AUTH_ARGS[@]}" 2>&1) || true
    echo "${WAIT_OUTPUT}"

    NOTARIZE_STATUS=$(echo "${WAIT_OUTPUT}" | grep "  status:" | awk '{print $2}')

    if [ "${NOTARIZE_STATUS}" != "Accepted" ]; then
        echo -e "${RED}✗ Notarization failed (status: ${NOTARIZE_STATUS})${NC}"
        if [ -n "${SUBMISSION_ID}" ]; then
            echo ""
            echo -e "${YELLOW}Fetching notarization log for submission ${SUBMISSION_ID}...${NC}"
            xcrun notarytool log "${SUBMISSION_ID}" "${NOTARIZE_AUTH_ARGS[@]}" 2>&1
        fi
        exit 1
    fi

    echo -e "${YELLOW}Stapling notarization ticket...${NC}"
    xcrun stapler staple "${FINAL_DMG}"

    echo -e "${GREEN}✓ DMG notarized and stapled${NC}"
    echo ""
fi

# Show final results
DMG_SIZE=$(du -sh "${FINAL_DMG}" | cut -f1)
DMG_CHECKSUM=$(shasum -a 256 "${FINAL_DMG}" | cut -d' ' -f1)

echo "=================================================="
echo "  DMG Creation Complete"
echo "=================================================="
echo ""
echo -e "${BLUE}Output:${NC}"
echo "  ${FINAL_DMG}"
echo ""
echo -e "${BLUE}Details:${NC}"
echo "  Size: ${DMG_SIZE}"
echo "  SHA256: ${DMG_CHECKSUM}"
echo ""
echo -e "${BLUE}Status:${NC}"
if [ "$SIGN" = true ]; then
    echo "  ✅ Code signed"
elif [ "$DEV_SIGN" = true ]; then
    echo "  👷 Dev code signed"
else
    echo "  ⚠️ Not code signed"
fi

if [ "$NOTARIZE" = true ]; then
    echo "  ✅ Notarized"
else
    echo "  ⚠️ Not notarized"
fi
echo ""

# Verification
echo -e "${YELLOW}Verifying DMG...${NC}"
hdiutil verify "${FINAL_DMG}"
echo -e "${GREEN}✓ DMG verified${NC}"
echo ""
