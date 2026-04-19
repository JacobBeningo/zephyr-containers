#!/usr/bin/env bash
# Build Zephyr firmware inside the container with build output on the host.
#
# Usage:
#   ./build.sh frdm_mcxn947/mcxn947/cpu0          # incremental
#   ./build.sh frdm_mcxn947/mcxn947/cpu0 clean     # delete build dir first
#
# The build/ directory lands on the host so VS Code (IntelliSense, debug) can
# use compile_commands.json and zephyr.elf directly.

set -euo pipefail

BOARD="${1:?Usage: $0 <board> [clean]}"
CLEAN="${2:-}"
IMAGE="${IMAGE:-ghcr.io/jacobbeningo/zephyr-base:nxp-v4.4.0}"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${APP_DIR}/build"

# Stale cmake caches from a different Zephyr installation will break the build.
# Always wipe when switching boards or when explicitly requested.
if [ "${CLEAN}" = "clean" ] || \
   ( [ -f "${BUILD_DIR}/CMakeCache.txt" ] && \
     ! grep -q "ZEPHYR_BASE:PATH=/workdir/zephyr" "${BUILD_DIR}/CMakeCache.txt" 2>/dev/null ); then
    echo "Removing stale build directory..."
    rm -rf "${BUILD_DIR}"
fi

docker run --rm \
    -v "${APP_DIR}:/workdir/app" \
    -v "${HOME}/.cache/zephyr-ccache:/home/zephyr/.ccache" \
    -e CCACHE_DIR=/home/zephyr/.ccache \
    "${IMAGE}" \
    west build -b "${BOARD}" /workdir/app -d /workdir/app/build
