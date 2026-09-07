#!/bin/bash
#
#  SPDX-License-Identifier: MIT
#  Copyright (c) 2026 Paal Øye-Strømme
#
#  ship_pkg.sh
#  Rugzak
#
# Build PKG for testing and development
#

set -euo pipefail

PARENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

exec "${PARENT_DIR}/create_pkg.sh" Rugzak "$@"
