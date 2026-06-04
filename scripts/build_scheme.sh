#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  build_scheme.sh
#
# Build $scheme without installing in for testing and development
#

set -euo pipefail

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

CLEAN=false
VERBOSE=false
DEV_SIGN=false

SCHEME=""
PROJECT=""
ARTIFACT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --artifact)
             ARTIFACT="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --debug)
            BUILD_CONFIG="Debug"
            shift
            ;;
        --dev-sign)
            DEV_SIGN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 SCHEME [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  SCHEME              Xcode scheme to build (required)"
            echo ""
            echo "Options:"
            echo "  --project PROJECT   Xcode project name (default: same as SCHEME)"
            echo "  --artifact ARTIFACT Tangible result of building SCHEME (default: SCHEME.app)"
            echo "  --clean             Clean build (remove derived data)"
            echo "  --debug             Build Debug configuration (default: Release)"
            echo "  --dev-sign          Sign with Apple Development certificate"
            echo "  --verbose,-v        Show detailed build output"
            echo "  --help,-h           Show this help message"
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
ARTIFACT="${ARTIFACT:-"${SCHEME}.app"}"

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_ROOT}/${PROJECT}.xcodeproj"
BUILD_CONFIG="${BUILD_CONFIG:-Release}"
DERIVED_DATA="${PROJECT_ROOT}/.tmp/DerivedData"

echo "=================================================="
echo "  ${SCHEME} Build"
echo "=================================================="
echo ""
echo "Configuration: ${BUILD_CONFIG}"
echo "Project:       ${XCODE_PROJECT}"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Cleaning derived data...${NC}"
    rm -rf "${DERIVED_DATA}"
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# Determine grep filter for build output
if [ "$VERBOSE" = true ]; then
    GREP_FILTER="cat"
else
    GREP_FILTER="grep -E '(error:|warning:|Build Succeeded|Build Failed|\*\* BUILD)' || true"
fi

BUILD_LOG="${PROJECT_ROOT}/.tmp/build_${BUILD_CONFIG}.log"
mkdir -p "${PROJECT_ROOT}/.tmp"

echo -e "${YELLOW}Building (${BUILD_CONFIG})...${NC}"

set +e
if [ "$DEV_SIGN" = true ]; then
    echo "  Code signing with: Apple Development"
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme $SCHEME \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -destination "generic/platform=macOS" \
        build \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="Apple Development" \
        CODE_SIGNING_REQUIRED=YES \
        2>&1 | tee "${BUILD_LOG}" | eval "$GREP_FILTER"
else
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme $SCHEME \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -destination "generic/platform=macOS" \
        build \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee "${BUILD_LOG}" | eval "$GREP_FILTER"
fi
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [ $BUILD_STATUS -ne 0 ]; then
    echo -e "${RED}✗ Build failed (exit code ${BUILD_STATUS})${NC}"
    echo ""
    echo -e "${RED}=== Full build log ===${NC}"
    cat "${BUILD_LOG}"
    exit 1
fi

ARTIFACT_PATH="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/${ARTIFACT}"

if [ ! \( -d "$ARTIFACT_PATH" -o -x "$ARTIFACT_PATH" \) ]; then
    echo -e "${RED}✗ ${ARTIFACT} not found in ${ARTIFACT_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${SCHEME} built successfully${NC}"
echo ""

# Show build products
echo "=================================================="
echo "  Build Complete"
echo "=================================================="
echo ""
echo -e "${BLUE}Build products location:${NC}"
echo "  ${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/"
echo ""
echo -e "${BLUE}Built artifacts:${NC}"
echo "  ${ARTIFACT}:  $(du -sh $ARTIFACT_PATH | cut -f1)"
echo ""

# Show code signature information
SIGNATURE_INFO=$(codesign -dvvv $ARTIFACT_PATH 2>&1)

if echo "${SIGNATURE_INFO}" | grep -q "Signature=adhoc"; then
    echo -e "${YELLOW}Code Signature:${NC}"
elif echo "${SIGNATURE_INFO}" | grep -q "Authority=Apple Development"; then
    TEAM_ID=$(echo "${SIGNATURE_INFO}" | grep "TeamIdentifier=" | cut -d'=' -f2)
    echo -e "${BLUE}Code Signature:${NC}"
    echo "  Type: Development"
    echo "  Team: ${TEAM_ID}"
else
    echo -e "${BLUE}Code Signature:${NC}"
    echo "  $(echo "${SIGNATURE_INFO}" | grep "Authority=" | head -1 | cut -d'=' -f2)"
fi
echo ""
