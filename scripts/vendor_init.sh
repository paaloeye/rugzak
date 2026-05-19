#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  vendor_init.sh
#  Rugzak
#
#  Checks out vendored dependencies into vendor/ if not already present.
#  Safe to run multiple times — exits early when deps are already at the
#  correct commit.
#
#  Usage: bash scripts/vendor_init.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${ROOT_DIR}/vendor"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${YELLOW}▶ $*${NC}"; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
err()  { echo -e "${RED}✗ $*${NC}" >&2; }
info() { echo -e "${BLUE}  $*${NC}"; }

# ---------------------------------------------------------------------------
# Vendor entries — one line per dep: "name|url|commit"
# ---------------------------------------------------------------------------
VENDORS="
fuse-archive|https://github.com/google/fuse-archive.git|27a902747a354a410852af3ae9735135789bd465
libb2|https://github.com/BLAKE2/libb2.git|2c5142f12a2cd52f3ee0a43e50a3a76f75badf85
libarchive|https://github.com/libarchive/libarchive.git|a651b4fcd8341a02bd36a20008c55f1aa9bd950f
"

command -v git &>/dev/null || { err "git not found"; exit 1; }

mkdir -p "${VENDOR_DIR}"

echo "=================================================="
echo "  Rugzak — init vendored dependencies"
echo "=================================================="
echo ""

while IFS='|' read -r NAME URL COMMIT; do
    [[ -z "${NAME}" ]] && continue
    DEST="${VENDOR_DIR}/${NAME}"

    if [[ -d "${DEST}/.git" ]]; then
        CURRENT=$(git -C "${DEST}" rev-parse HEAD 2>/dev/null || echo "unknown")
        if [[ "${CURRENT}" == "${COMMIT}" ]]; then
            ok "${NAME}: already at ${COMMIT:0:12}"
            continue
        fi
        log "${NAME}: updating to ${COMMIT:0:12}..."
        git -C "${DEST}" fetch --quiet origin
        git -C "${DEST}" checkout --quiet "${COMMIT}"
        ok "${NAME}: ${COMMIT:0:12}"
    else
        log "${NAME}: cloning from ${URL}..."
        info "Pinned commit: ${COMMIT:0:12}"
        git clone --quiet "${URL}" "${DEST}"
        git -C "${DEST}" checkout --quiet "${COMMIT}"
        ok "${NAME}: ${COMMIT:0:12}"
    fi
done <<< "${VENDORS}"

echo ""
ok "All vendored dependencies ready."
echo ""
