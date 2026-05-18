#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  create_dmg.sh
#  Rukzak
#
# Build Rugzak without installing in Release configuration for testing and development
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

while [[ $# -gt 0 ]]; do
    case $1 in
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
            echo "Usage: $0 [TARGET] [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean       Clean build (remove derived data)"
            echo "  --debug       Build Debug configuration (default: Release)"
            echo "  --dev-sign    Sign with Apple Development certificate (preserves TCC permissions)"
            echo "  --verbose,-v  Show detailed build output"
            echo "  --help,-h     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_ROOT}/Rugzak.xcodeproj"
BUILD_CONFIG="${BUILD_CONFIG:-Release}"
DERIVED_DATA="${PROJECT_ROOT}/.tmp/DerivedData"

# Parse arguments
CLEAN=false
VERBOSE=false
DEV_SIGN=false

echo "=================================================="
echo "  Rugzak Build"
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
    GREP_FILTER="grep -E '(error|warning|Build Succeeded|Build Failed|\*\* BUILD)' || true"
fi

echo -e "${YELLOW}Building (${BUILD_CONFIG})...${NC}"

if [ "$DEV_SIGN" = true ]; then
    echo "  Code signing with: Apple Development"
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "Rugzak" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -arch arm64 -arch x86_64 \
        build \
        CODE_SIGN_IDENTITY="Apple Development" \
        CODE_SIGNING_REQUIRED=YES \
        | eval "$GREP_FILTER"
else
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "Rugzak" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${DERIVED_DATA}" \
        -arch arm64 -arch x86_64 \
        build \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        | eval "$GREP_FILTER"
fi

BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -ne 0 ]; then
    echo -e "${RED}✗ build failed${NC}"
    exit 1
fi

if [ ! -d "${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/Rugzak.app" ]; then
    echo -e "${RED}✗ Rugzak not found in build products${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Rugzak.app built successfully${NC}"
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
echo "  Rugzak.app"
echo ""

# Show file sizes
echo "  App:  $(du -sh "${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/Rugzak.app" | cut -f1)"
echo ""

# Show code signature information
APP_PATH="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}/Rugzak.app"
SIGNATURE_INFO=$(codesign -dvvv "${APP_PATH}" 2>&1)

if echo "${SIGNATURE_INFO}" | grep -q "Signature=adhoc"; then
    echo -e "${YELLOW}Code Signature:${NC}"
    echo "  Type: Ad-hoc (TCC permissions will NOT persist)"
    echo "  Tip: Use --dev-sign to preserve permissions between builds"
elif echo "${SIGNATURE_INFO}" | grep -q "Authority=Apple Development"; then
    TEAM_ID=$(echo "${SIGNATURE_INFO}" | grep "TeamIdentifier=" | cut -d'=' -f2)
    echo -e "${BLUE}Code Signature:${NC}"
    echo "  Type: Development"
    echo "  Team: ${TEAM_ID}"
    echo -e "  ${GREEN}✓ TCC permissions will persist between builds${NC}"
else
    echo -e "${BLUE}Code Signature:${NC}"
    echo "  $(echo "${SIGNATURE_INFO}" | grep "Authority=" | head -1 | cut -d'=' -f2)"
fi
echo ""
