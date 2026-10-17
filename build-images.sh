#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

REGISTRY="${REGISTRY:-fenix}"
TAG="${TAG:-local}"
TARGET="${TARGET:-mise}"
CLOUD_CLIS="${CLOUD_CLIS:-}"
CODING_AGENTS="${CODING_AGENTS:-}"

IMAGE_VERSION="${IMAGE_VERSION:-dev}"
SOURCE_COMMIT="${SOURCE_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

exec docker build \
  --target "${TARGET}" \
  --build-arg "CLOUD_CLIS=${CLOUD_CLIS}" \
  --build-arg "CODING_AGENTS=${CODING_AGENTS}" \
  --build-arg "IMAGE_VERSION=${IMAGE_VERSION}" \
  --build-arg "SOURCE_COMMIT=${SOURCE_COMMIT}" \
  --build-arg "BUILD_DATE=${BUILD_DATE}" \
  -t "${REGISTRY}-base:${TAG}" .
