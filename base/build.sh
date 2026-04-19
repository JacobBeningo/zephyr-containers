#!/usr/bin/env bash
set -euo pipefail

SDK_VERSION="${SDK_VERSION:-1.0.1}"
MANIFEST_FILE="${MANIFEST_FILE:-nxp-v4.4.0.yml}"
REGISTRY="${REGISTRY:-ghcr.io/jacobbeningo}"
PUSH="${PUSH:-0}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
RUN_SMOKE_TEST="${RUN_SMOKE_TEST:-0}"

# Derive image tag from the manifest filename (strip .yml)
IMAGE_TAG="${MANIFEST_FILE%.yml}"
IMAGE="${REGISTRY}/zephyr-base:${IMAGE_TAG}"

CACHE_ARGS=()
EXTRA_ARGS=()
if [ "${PUSH}" = "1" ]; then
    EXTRA_ARGS+=(--push)
    CACHE_ARGS+=(
        --cache-from "type=registry,ref=${IMAGE}-cache"
        --cache-to   "type=registry,ref=${IMAGE}-cache,mode=max"
    )
else
    EXTRA_ARGS+=(--load)
    PLATFORMS="linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
fi

docker buildx build \
    --platform "${PLATFORMS}" \
    --build-arg SDK_VERSION="${SDK_VERSION}" \
    --build-arg MANIFEST_FILE="${MANIFEST_FILE}" \
    --build-arg REGISTRY="${REGISTRY}" \
    --build-arg RUN_SMOKE_TEST="${RUN_SMOKE_TEST}" \
    --tag "${IMAGE}" \
    --tag "${REGISTRY}/zephyr-base:latest-nxp" \
    ${CACHE_ARGS[@]+"${CACHE_ARGS[@]}"} \
    "${EXTRA_ARGS[@]}" \
    "$(dirname "$0")"
