#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  create_pkg.sh
#
# Build and create PKG distribution:
#
# 1. Builds in Release configuration
# 2. Creates a flat installer package (.pkg) that installs the app to /Applications
# 3. Optionally code signs (Developer ID Installer) and notarizes the package
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
INSTALLER_IDENTITY=""
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
        --installer-identity)
            INSTALLER_IDENTITY="$2"
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
            echo "  SCHEME                         Xcode scheme to build (required)"
            echo ""
            echo "Options:"
            echo "  --project PROJECT              Xcode project name (default: same as SCHEME)"
            echo "  --clean                        Clean build (remove derived data)"
            echo "  --dev-sign                     Sign app with Apple Development"
            echo "  --sign IDENTITY                Code sign app with specified identity"
            echo "                                 (e.g., 'Developer ID Application: Name (TEAMID)')"
            echo "  --installer-identity IDENTITY  Sign PKG with specified installer identity"
            echo "                                 (default: 'Developer ID Installer' derived from --sign)"
            echo "  --notarize TEAM_ID             Notarize PKG (requires --sign)"
            echo "  --keychain-profile NAME        Keychain profile for notarytool (local dev)"
            echo "  --apple-id EMAIL               Apple ID for notarization"
            echo "  --password PASS                App-specific password (use @keychain:NAME to read from Keychain)"
            echo "  --api-key PATH                 Path to App Store Connect API key .p8 file (CI preferred)"
            echo "  --api-key-id ID                App Store Connect API key ID"
            echo "  --api-issuer ID                App Store Connect issuer ID"
            echo "  --verbose,-v                   Show detailed build output"
            echo "  --help,-h                      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 SCHEME                                                    # Basic PKG (unsigned)"
            echo "  $0 SCHEME --dev-sign                                         # Development signed"
            echo "  $0 SCHEME --sign \"Developer ID Application: Name (TEAMID)\"  # Distribution signed PKG"
            echo "  $0 SCHEME --sign \"Developer ID Application: Name (TEAMID)\" \\"
            echo "            --notarize TEAMID --keychain-profile AC_PASSWORD"
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

# Derive installer identity from app signing identity when not provided explicitly.
# "Developer ID Application: Name (TEAMID)" → "Developer ID Installer: Name (TEAMID)"
if [ "$SIGN" = true ] && [ -z "$INSTALLER_IDENTITY" ]; then
    INSTALLER_IDENTITY="${SIGNING_IDENTITY/Developer ID Application/Developer ID Installer}"
fi

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_ROOT}/${PROJECT}.xcodeproj"
BUILD_CONFIG="Release"
DERIVED_DATA="${PROJECT_ROOT}/.tmp/DerivedData"
DIST_DIR="${PROJECT_ROOT}/.tmp/dist"
PKG_DIR="${PROJECT_ROOT}/.dist"

echo "=================================================="
echo "  ${SCHEME} PKG Creator"
echo "=================================================="
echo ""

mkdir -p "${DIST_DIR}"
mkdir -p "${PKG_DIR}"

if [ "$VERBOSE" = true ]; then
    GREP_FILTER="cat"
else
    GREP_FILTER="grep -E '(error:|warning:|Build Succeeded|Build Failed|\*\* BUILD)' || true"
fi

cd "${PROJECT_ROOT}"

if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning derived data...${NC}"
    rm -rf "${DERIVED_DATA}"
    echo -e "${GREEN}✓ Clean done${NC}"
    echo ""
fi

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
    exit 1
fi

APP_PATH="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/${SCHEME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}✗ ${SCHEME}.app not found in ${APP_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${SCHEME}.app built successfully${NC}"
echo ""

# Extract version and identity information from the built app
VERSION=$(defaults read "${APP_PATH}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
BUILD=$(defaults read "${APP_PATH}/Contents/Info.plist" CFBundleVersion 2>/dev/null)
BUNDLE_ID=$(defaults read "${APP_PATH}/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)
GIT_COMMIT=$(defaults read "${APP_PATH}/Contents/Info.plist" GitCommitHash 2>/dev/null || echo "unknown")
GIT_STATUS=$(defaults read "${APP_PATH}/Contents/Info.plist" GitBuildStatus 2>/dev/null || echo "unknown")

echo -e "${BLUE}Version Information:${NC}"
echo "  Version:    ${VERSION}"
echo "  Build:      ${BUILD}"
echo "  Bundle ID:  ${BUNDLE_ID}"
echo "  Git commit: ${GIT_COMMIT}"
echo "  Git status: ${GIT_STATUS}"
echo ""

# Build PKG name with git information
PKG_NAME="${SCHEME}-${VERSION}-${GIT_COMMIT}"
if [ "${GIT_STATUS}" = "dirty" ]; then
    PKG_NAME="${PKG_NAME}-dirty"
fi

COMPONENT_PKG="${DIST_DIR}/${PKG_NAME}-component.pkg"
FINAL_PKG="${PKG_DIR}/${PKG_NAME}.pkg"

# Remove stale artefacts
rm -f "${COMPONENT_PKG}" "${FINAL_PKG}"

echo -e "${YELLOW}Creating PKG...${NC}"

PKGBUILD_ARGS=(
    --component "${APP_PATH}"
    --install-location /Applications
    --identifier "${BUNDLE_ID}"
    --version "${VERSION}"
)

if [ "$SIGN" = true ]; then
    echo "  Installer identity: ${INSTALLER_IDENTITY}"
    PKGBUILD_ARGS+=(--sign "${INSTALLER_IDENTITY}" --timestamp)
fi

pkgbuild "${PKGBUILD_ARGS[@]}" "${FINAL_PKG}"

echo -e "${GREEN}✓ PKG created${NC}"
echo ""

# Notarize if requested
if [ "$NOTARIZE" = true ]; then
    if [ "$SIGN" != true ]; then
        echo -e "${RED}Error: --notarize requires --sign${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Submitting PKG for notarization...${NC}"
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

    SUBMIT_OUTPUT=$(xcrun notarytool submit "${FINAL_PKG}" \
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
    xcrun stapler staple "${FINAL_PKG}"

    echo -e "${GREEN}✓ PKG notarized and stapled${NC}"
    echo ""
fi

# Show final results
PKG_SIZE=$(du -sh "${FINAL_PKG}" | cut -f1)
PKG_CHECKSUM=$(shasum -a 256 "${FINAL_PKG}" | cut -d' ' -f1)

echo "=================================================="
echo "  PKG Creation Complete"
echo "=================================================="
echo ""
echo -e "${BLUE}Output:${NC}"
echo "  ${FINAL_PKG}"
echo ""
echo -e "${BLUE}Details:${NC}"
echo "  Size:   ${PKG_SIZE}"
echo "  SHA256: ${PKG_CHECKSUM}"
echo ""
echo -e "${BLUE}Status:${NC}"
if [ "$SIGN" = true ]; then
    echo "  ✅ App code signed"
    echo "  ✅ PKG installer signed"
elif [ "$DEV_SIGN" = true ]; then
    echo "  👷 App dev code signed"
    echo "  ⚠️  PKG not installer-signed"
else
    echo "  ⚠️  Not code signed"
fi

if [ "$NOTARIZE" = true ]; then
    echo "  ✅ Notarized"
else
    echo "  ⚠️  Not notarized"
fi
echo ""

# Verify the package is well-formed
echo -e "${YELLOW}Verifying PKG...${NC}"
pkgutil --check-signature "${FINAL_PKG}" 2>/dev/null || pkgutil --payload-files "${FINAL_PKG}" > /dev/null
echo -e "${GREEN}✓ PKG verified${NC}"
echo ""
