#!/usr/bin/env bash
set -euo pipefail

SDK_VERSION="${SDK_VERSION:-1.0.1}"
REGISTRY="${REGISTRY:-ghcr.io/jacobbeningo}"
PUSH="${PUSH:-0}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# SHA-256 checksums for SDK ${SDK_VERSION}
# Retrieve from: https://github.com/zephyrproject-rtos/sdk-ng/releases/tag/v${SDK_VERSION}
SDK_SHA256_AMD64="${SDK_SHA256_AMD64:-}"
SDK_SHA256_ARM64="${SDK_SHA256_ARM64:-}"

IMAGE="${REGISTRY}/zephyr-sdk:${SDK_VERSION}"

CACHE_ARGS=()
EXTRA_ARGS=()
if [ "${PUSH}" = "1" ]; then
    EXTRA_ARGS+=(--push)
    CACHE_ARGS+=(
        --cache-from "type=registry,ref=${IMAGE}-cache"
        --cache-to   "type=registry,ref=${IMAGE}-cache,mode=max"
    )
else
    # Without --push, multi-arch builds can't be loaded locally; use --load for single-arch
    EXTRA_ARGS+=(--load)
    PLATFORMS="linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
fi

docker buildx build \
    --platform "${PLATFORMS}" \
    --build-arg SDK_VERSION="${SDK_VERSION}" \
    --build-arg SDK_SHA256_AMD64="${SDK_SHA256_AMD64}" \
    --build-arg SDK_SHA256_ARM64="${SDK_SHA256_ARM64}" \
    --tag "${IMAGE}" \
    --tag "${REGISTRY}/zephyr-sdk:latest" \
    ${CACHE_ARGS[@]+"${CACHE_ARGS[@]}"} \
    "${EXTRA_ARGS[@]}" \
    "$(dirname "$0")"
