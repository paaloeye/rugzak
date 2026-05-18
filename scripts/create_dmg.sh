#!/usr/bin/env bash
#
# create_dmg.sh - Build and create DMG distribution
#
# This script:
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

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_ROOT}/Rugzak.xcodeproj"
BUILD_CONFIG="Release"
DERIVED_DATA="${PROJECT_ROOT}/.tmp/DerivedData"
DIST_DIR="${PROJECT_ROOT}/.tmp/dist"
DMG_DIR="${PROJECT_ROOT}/.dist"

# Get version from Info.plist (will be built first, so we check after build)
APP_NAME="Rugzak"           # Xcode scheme/target name
APP_DISPLAY_NAME="Rugzak"   # Human-readable display name
DMG_NAME="Rugzak"  # DMG file prefix

# Parse arguments
CLEAN=false
SIGN=false
DEV_SIGN=false
NOTARIZE=false
VERBOSE=false
SIGNING_IDENTITY=""
TEAM_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
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
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean                    Clean build (remove derived data)"
            echo "  --dev-sign                 Sign with Apple Development (preserves TCC permissions)"
            echo "  --sign IDENTITY            Code sign with specified identity (e.g., 'Developer ID Application')"
            echo "  --notarize TEAM_ID         Notarize DMG (requires --sign)"
            echo "  --verbose,-v               Show detailed build output"
            echo "  --help,-h                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Basic DMG creation (unsigned)"
            echo "  $0 --dev-sign                         # Development signed (TCC permissions persist)"
            echo "  $0 --sign \"Developer ID Application: Name\" # Distribution signed DMG"
            echo "  $0 --sign \"Developer ID Application: Name\" --notarize TEAM_ID  # Signed and notarized"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "=================================================="
echo "  Rugzak DMG Creator"
echo "=================================================="
echo ""

# Create output directories
mkdir -p "${DIST_DIR}"
mkdir -p "${DMG_DIR}"

# Determine grep filter for build output
if [ "$VERBOSE" = true ]; then
    GREP_FILTER="cat"
else
    GREP_FILTER="grep -E '(error|warning|Build Succeeded|Build Failed|\*\* BUILD)' || true"
fi

cd "${PROJECT_ROOT}"

# Build  app
echo -e "${YELLOW}Building ${APP_NAME}.app (${BUILD_CONFIG})...${NC}"

if [ "$SIGN" = true ] || [ "$DEV_SIGN" = true ]; then
    echo "  Code signing with: ${SIGNING_IDENTITY}"
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${APP_NAME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -arch arm64 -arch x86_64 \
        build \
        CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
        CODE_SIGNING_REQUIRED=YES \
        | eval "$GREP_FILTER"
else
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${APP_NAME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -arch arm64 -arch x86_64 \
        build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        | eval "$GREP_FILTER"
fi

BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -ne 0 ]; then
    echo -e "${RED}✗ ${APP_NAME}.app build failed${NC}"
    exit 1
fi

APP_PATH="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}✗ ${APP_NAME}.app not found in build products${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${APP_NAME}.app built successfully${NC}"
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
DMG_NAME="${APP_NAME}-${VERSION}-${GIT_COMMIT_FROM_PLIST}"
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
    -volname "${APP_DISPLAY_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    "${TEMP_DMG}"

# Mount the DMG to set custom attributes
MOUNT_DIR="${DIST_DIR}/mount"
mkdir -p "${MOUNT_DIR}"

hdiutil attach "${TEMP_DMG}" -mountpoint "${MOUNT_DIR}" -nobrowse

# Set custom icon positions and window size using AppleScript
osascript <<EOF || true
tell application "Finder"
    tell disk "${APP_DISPLAY_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "${APP_NAME}.app" of container window to {125, 175}
        set position of item "Applications" of container window to {375, 175}
        close
        open
        update without registering applications
        delay 2
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
rm -rf "${MOUNT_DIR}"

echo -e "${GREEN}✓ DMG created${NC}"
echo ""

# Code sign DMG if requested (skip for dev-sign as DMG signing isn't needed for TCC)
if [ "$SIGN" = true ]; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    codesign --sign "${SIGNING_IDENTITY}" \
        --force \
        --timestamp \
        "${FINAL_DMG}"
    echo -e "${GREEN}✓ DMG signed${NC}"
elif [ "$DEV_SIGN" = true ]; then
    echo -e "${BLUE}Skipping DMG signing for development build${NC}"
    echo "  (App is signed, which is sufficient for TCC permissions)"
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

    xcrun notarytool submit "${FINAL_DMG}" \
        --team-id "${TEAM_ID}" \
        --wait

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
else
    echo "  ⚠️  Not code signed"
fi

if [ "$NOTARIZE" = true ]; then
    echo "  ✅ Notarized"
else
    echo "  ⚠️  Not notarized"
fi
echo ""

# Verification
echo -e "${YELLOW}Verifying DMG...${NC}"
hdiutil verify "${FINAL_DMG}"
echo -e "${GREEN}✓ DMG verified${NC}"
echo ""
