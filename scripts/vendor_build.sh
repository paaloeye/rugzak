#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  vendor_build.sh
#  Rugzak
#
#  Builds libarchive (static) and fuse-archive (universal arm64+x86_64) from vendored sources.
#  Output: vendor/out/fuse-archive
#
#  Called by the Xcode "Build fuse-archive" run-script phase. Safe to run standalone.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${ROOT_DIR}/vendor"
OUT_DIR="${VENDOR_DIR}/out"
LIBARCHIVE_SRC="${VENDOR_DIR}/libarchive"
FUSE_SRC="${VENDOR_DIR}/fuse-archive"
XZ_SRC="${VENDOR_DIR}/xz"
OUT_BINARY="${OUT_DIR}/fuse-archive"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${YELLOW}▶ $*${NC}"; }
ok()  { echo -e "${GREEN}✓ $*${NC}"; }
err() { echo -e "${RED}✗ $*${NC}" >&2; }

# ---------------------------------------------------------------------------
# Skip if output is already fresh (Xcode input/output tracking also handles
# this, but we check here for standalone runs too)
# ---------------------------------------------------------------------------
if [[ -f "${OUT_BINARY}" ]]; then
    if ! find "${FUSE_SRC}" -name "*.cc" -newer "${OUT_BINARY}" | grep -q .; then
        if ! find "${LIBARCHIVE_SRC}/libarchive" -name "*.c" -newer "${OUT_BINARY}" | grep -q .; then
            if ! find "${XZ_SRC}/src/liblzma" -name "*.c" -newer "${OUT_BINARY}" | grep -q .; then
                ok "fuse-archive binary is up to date — skipping build"
                exit 0
            fi
        fi
    fi
fi

mkdir -p "${OUT_DIR}"

# ---------------------------------------------------------------------------
# Ensure vendored sources are present and at the correct commit
# ---------------------------------------------------------------------------
bash "${SCRIPT_DIR}/vendor_init.sh"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
command -v cmake &>/dev/null || { err "cmake not found"; exit 1; }
# Boost is a header-only dep of fuse-archive — check via pkg-config or the canonical Homebrew path
if ! pkg-config --exists boost 2>/dev/null && ! [[ -d /opt/homebrew/opt/boost/include || -d /usr/local/opt/boost/include ]]; then
    err "Boost not found. Install with: brew install boost"
    exit 1
fi

SYSROOT=$(xcrun --sdk macosx --show-sdk-path)
NCPU=$(sysctl -n hw.ncpu)
# Honour Xcode's deployment target when run as a build phase; fall back to a
# safe minimum for standalone runs.
MACOS_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.6}"

# fuse3 pkg-config flags (macFUSE ships fuse3-compatible headers at /usr/local)
if ! pkg-config --exists fuse3 2>/dev/null; then
    err "fuse3 pkg-config not found. Install macFUSE from https://macfuse.github.io/ or brew install macfuse"
    exit 1
fi
FUSE3_CFLAGS=$(pkg-config --cflags fuse3)
FUSE3_LIBS=$(pkg-config --libs fuse3)

# Use macOS system compression and iconv — no Homebrew required.
# zlib, bzip2, and iconv ship with every macOS install.
# zstd and lz4 are disabled in libarchive cmake below; xz/lzma is vendored.
COMP_LIBS="-lz -lbz2 -liconv"

# ---------------------------------------------------------------------------
# Build liblzma (static) for a single arch
# ---------------------------------------------------------------------------
build_liblzma_arch() {
    local ARCH="$1"
    local PREFIX="${OUT_DIR}/liblzma_${ARCH}"
    local BUILD="${OUT_DIR}/.cmake_liblzma_${ARCH}"

    if [[ -f "${PREFIX}/lib/liblzma.a" ]]; then
        echo "  liblzma (${ARCH}): cached"
        return
    fi

    log "Building liblzma (${ARCH})..."
    mkdir -p "${BUILD}"

    local LOG="${OUT_DIR}/.liblzma_${ARCH}.log"

    cmake -S "${XZ_SRC}" -B "${BUILD}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_SYSROOT="${SYSROOT}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DCREATE_XZ_SYMLINKS=OFF \
        -DCREATE_LZMA_SYMLINKS=OFF \
        -DXZ_BUILD_XZ=OFF \
        -DXZ_BUILD_XZDEC=OFF \
        -DXZ_BUILD_LZMADEC=OFF \
        -DXZ_BUILD_LZMAINFO=OFF \
        -DXZ_BUILD_SCRIPTS=OFF \
        -DXZ_ENABLE_DOXYGEN=OFF \
        -DXZ_ENABLE_NLS=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_Intl=ON \
        -DCMAKE_DISABLE_FIND_PACKAGE_Gettext=ON \
        -DCMAKE_C_FLAGS="-arch ${ARCH}" \
        -Wno-dev \
        >"${LOG}" 2>&1 || { err "cmake configure failed (liblzma ${ARCH})"; cat "${LOG}"; return 1; }

    cmake --build "${BUILD}" --parallel "${NCPU}" >>"${LOG}" 2>&1 \
        || { err "cmake build failed (liblzma ${ARCH})"; cat "${LOG}"; return 1; }
    cmake --install "${BUILD}" >>"${LOG}" 2>&1 \
        || { err "cmake install failed (liblzma ${ARCH})"; cat "${LOG}"; return 1; }

    ok "liblzma (${ARCH}): ${PREFIX}/lib/liblzma.a"
}

build_liblzma_arch arm64
build_liblzma_arch x86_64

# ---------------------------------------------------------------------------
# Build libarchive (static) for a single arch
# ---------------------------------------------------------------------------
build_libarchive_arch() {
    local ARCH="$1"
    local PREFIX="${OUT_DIR}/libarchive_${ARCH}"
    local BUILD="${OUT_DIR}/.cmake_libarchive_${ARCH}"
    local LZMA_A="${OUT_DIR}/liblzma_${ARCH}/lib/liblzma.a"
    local LZMA_INC="${OUT_DIR}/liblzma_${ARCH}/include"

    if [[ -f "${PREFIX}/lib/libarchive.a" ]]; then
        echo "  libarchive (${ARCH}): cached"
        return
    fi

    log "Building libarchive (${ARCH})..."
    mkdir -p "${BUILD}"

    local LOG="${OUT_DIR}/.libarchive_${ARCH}.log"

    cmake -S "${LIBARCHIVE_SRC}" -B "${BUILD}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_SYSROOT="${SYSROOT}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_TARGET}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_TEST=OFF \
        -DENABLE_TAR=OFF \
        -DENABLE_CPIO=OFF \
        -DENABLE_CAT=OFF \
        -DENABLE_UNZIP=OFF \
        -DENABLE_WERROR=OFF \
        -DENABLE_OPENSSL=OFF \
        -DENABLE_MBEDTLS=OFF \
        -DENABLE_NETTLE=OFF \
        -DENABLE_LIBXML2=OFF \
        -DENABLE_EXPAT=OFF \
        -DENABLE_PCREPOSIX=OFF \
        -DENABLE_PCRE2POSIX=OFF \
        -DENABLE_ACL=OFF \
        -DENABLE_LIBB2=OFF \
        -DENABLE_LZMA=ON \
        -DLIBLZMA_LIBRARY="${LZMA_A}" \
        -DLIBLZMA_INCLUDE_DIR="${LZMA_INC}" \
        -DENABLE_LZ4=OFF \
        -DENABLE_ZSTD=OFF \
        -DCMAKE_C_FLAGS="-arch ${ARCH}" \
        -Wno-dev \
        >"${LOG}" 2>&1 || { err "cmake configure failed (libarchive ${ARCH})"; cat "${LOG}"; return 1; }

    cmake --build "${BUILD}" --parallel "${NCPU}" >>"${LOG}" 2>&1 \
        || { err "cmake build failed (libarchive ${ARCH})"; cat "${LOG}"; return 1; }
    cmake --install "${BUILD}" >>"${LOG}" 2>&1 \
        || { err "cmake install failed (libarchive ${ARCH})"; cat "${LOG}"; return 1; }

    ok "libarchive (${ARCH}): ${PREFIX}/lib/libarchive.a"
}

build_libarchive_arch arm64
build_libarchive_arch x86_64

# ---------------------------------------------------------------------------
# Build fuse-archive for a single arch, linked against our static libarchive
# ---------------------------------------------------------------------------
build_fuse_archive_arch() {
    local ARCH="$1"
    local ARCH_BIN="${OUT_DIR}/fuse_archive_${ARCH}"
    local ARCHIVE_A="${OUT_DIR}/libarchive_${ARCH}/lib/libarchive.a"
    local ARCHIVE_INC="${OUT_DIR}/libarchive_${ARCH}/include"
    local LZMA_A="${OUT_DIR}/liblzma_${ARCH}/lib/liblzma.a"
    local LZMA_INC="${OUT_DIR}/liblzma_${ARCH}/include"

    if [[ -f "${ARCH_BIN}" ]]; then
        echo "  fuse-archive (${ARCH}): cached"
        return
    fi

    log "Building fuse-archive (${ARCH})..."

    # Clean stale build artefacts from any previous arch build
    make -C "${FUSE_SRC}" clean >/dev/null 2>&1 || true

    local ARCH_FLAGS="-arch ${ARCH} -target ${ARCH}-apple-macos${MACOS_TARGET} -isysroot ${SYSROOT}"
    local LOG="${OUT_DIR}/.fuse_archive_${ARCH}.log"

    # Let the Makefile use fuse3 (its default on macOS via pkg-config), but
    # replace the libarchive half of PKG_* with our static build so we don't
    # depend on the user's Homebrew libarchive at runtime.
    make -C "${FUSE_SRC}" \
        PKG_CXXFLAGS="${FUSE3_CFLAGS} -I${ARCHIVE_INC} -I${LZMA_INC}" \
        PKG_LDFLAGS="${FUSE3_LIBS} ${ARCHIVE_A} ${LZMA_A} ${COMP_LIBS}" \
        CXXFLAGS="${ARCH_FLAGS}" \
        LDFLAGS="${ARCH_FLAGS}" \
        -j"${NCPU}" \
        >"${LOG}" 2>&1 || { err "make failed (fuse-archive ${ARCH})"; cat "${LOG}"; return 1; }

    cp "${FUSE_SRC}/out/fuse-archive" "${ARCH_BIN}"
    make -C "${FUSE_SRC}" clean >/dev/null 2>&1 || true

    ok "fuse-archive (${ARCH}): ${ARCH_BIN}"
}

build_fuse_archive_arch arm64
build_fuse_archive_arch x86_64

# ---------------------------------------------------------------------------
# Stitch into a universal binary
# ---------------------------------------------------------------------------
log "Creating universal binary..."
lipo -create \
    "${OUT_DIR}/fuse_archive_arm64" \
    "${OUT_DIR}/fuse_archive_x86_64" \
    -output "${OUT_BINARY}"
chmod +x "${OUT_BINARY}"

ok "fuse-archive universal: ${OUT_BINARY}"
echo "  $(file "${OUT_BINARY}")"
