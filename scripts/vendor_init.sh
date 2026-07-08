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
xz|https://github.com/tukaani-project/xz.git|ebb0e6789cefe3be71756881aa8f2009fda9938c
libb2|https://github.com/BLAKE2/libb2.git|2c5142f12a2cd52f3ee0a43e50a3a76f75badf85
zstd|https://github.com/facebook/zstd.git|f8745da6ff1ad1e7bab384bd1f9d742439278e99
lz4|https://github.com/lz4/lz4.git|ebb370ca83af193212df4dcbadcc5d87bc0de2f0
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
        # Consider up-to-date if HEAD equals pinned commit, or if pinned is an
        # ancestor (patches were cherry-picked on top and tracked in .applied_patches).
        if [[ "${CURRENT}" == "${COMMIT}" ]] || \
           git -C "${DEST}" merge-base --is-ancestor "${COMMIT}" HEAD 2>/dev/null; then
            ok "${NAME}: already at ${COMMIT:0:12}"
            continue
        fi
        log "${NAME}: updating to ${COMMIT:0:12}..."
        git -C "${DEST}" fetch --quiet origin
        git -C "${DEST}" checkout --quiet "${COMMIT}"
        rm -f "${DEST}/.applied_patches"
        ok "${NAME}: ${COMMIT:0:12}"
    else
        log "${NAME}: cloning from ${URL}..."
        info "Pinned commit: ${COMMIT:0:12}"
        git clone --quiet "${URL}" "${DEST}"
        git -C "${DEST}" checkout --quiet "${COMMIT}"
        rm -f "${DEST}/.applied_patches"
        ok "${NAME}: ${COMMIT:0:12}"
    fi
done <<< "${VENDORS}"

# ---------------------------------------------------------------------------
# Patches — one line per patch: "name|commit_sha"
# cherry-picked on top of the pinned vendor checkout.
# A .applied_patches file in each vendor dir tracks which SHAs are done.
# ---------------------------------------------------------------------------
PATCHES="
libarchive|75620d8ad714b3626d4881fbd23a9fdac1720353
libarchive|ecea0fe59630d206c25ae877d111f70d1742b62f
"

while IFS='|' read -r NAME SHA; do
    [[ -z "${NAME}" ]] && continue
    DEST="${VENDOR_DIR}/${NAME}"
    [[ -d "${DEST}/.git" ]] || { err "patch: ${NAME} not cloned"; exit 1; }

    APPLIED_FILE="${DEST}/.applied_patches"
    if [[ -f "${APPLIED_FILE}" ]] && grep -qF "${SHA}" "${APPLIED_FILE}" 2>/dev/null; then
        ok "${NAME}: patch ${SHA:0:12} already applied"
        continue
    fi

    # Fetch the commit from its origin if not already known locally
    if ! git -C "${DEST}" cat-file -e "${SHA}^{commit}" 2>/dev/null; then
        log "${NAME}: fetching patch commit ${SHA:0:12}..."
        REMOTE_URL=$(git -C "${DEST}" remote get-url origin)
        git -C "${DEST}" fetch --quiet "${REMOTE_URL}" "${SHA}" || {
            err "${NAME}: failed to fetch ${SHA:0:12}"; exit 1;
        }
    fi

    TITLE=$(git -C "${DEST}" log --format="%s" "${SHA}" -1 2>/dev/null)
    log "${NAME}: applying patch ${SHA:0:12} (${TITLE})..."
    git -C "${DEST}" cherry-pick --allow-empty "${SHA}" 2>/dev/null || {
        git -C "${DEST}" cherry-pick --abort 2>/dev/null || true
        err "${NAME}: patch ${SHA:0:12} failed to apply — resolve conflicts manually"
        exit 1
    }
    echo "${SHA}" >> "${APPLIED_FILE}"
    ok "${NAME}: patch ${SHA:0:12} applied"
done <<< "${PATCHES}"

echo ""
ok "All vendored dependencies ready."
echo ""
