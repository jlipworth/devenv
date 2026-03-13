#!/bin/bash
# ci/build-image.sh
# Build and optionally push a CI image to Docker Hub
#
# Usage:
#   ./ci/build-image.sh                          # Build default CI image only
#   ./ci/build-image.sh --push                   # Push default CI image (multi-arch)
#   ./ci/build-image.sh --image noadmin         # Build no-admin smoke-test image only
#   ./ci/build-image.sh --image noadmin --push  # Push no-admin smoke-test image (multi-arch)

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
DOCKERHUB_USER="${DOCKERHUB_USER:-jlipworth}"
TAG="${TAG:-latest}"
IMAGE_VARIANT="default"
PUSH_IMAGE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --push)
            PUSH_IMAGE="true"
            shift
            ;;
        --image)
            IMAGE_VARIANT="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: ./ci/build-image.sh [--push] [--image default|noadmin]" >&2
            exit 1
            ;;
    esac
done

case "$IMAGE_VARIANT" in
    default)
        IMAGE_NAME="gnu-files-ci"
        DOCKERFILE="ci/Dockerfile"
        ;;
    noadmin)
        IMAGE_NAME="gnu-files-noadmin"
        DOCKERFILE="ci/Dockerfile.noadmin"
        ;;
    *)
        echo "Unsupported image variant: $IMAGE_VARIANT" >&2
        echo "Expected one of: default, noadmin" >&2
        exit 1
        ;;
esac

FULL_IMAGE="${DOCKERHUB_USER}/${IMAGE_NAME}:${TAG}"

cd "$(dirname "$0")/.." # Go to repo root

# ============================================================================
# Build
# ============================================================================
if [[ "$PUSH_IMAGE" == "true" ]]; then
    # Multi-architecture build (amd64 + arm64) - requires buildx
    DATE_TAG=$(date +%Y.%m.%d)
    echo "Building multi-arch image: ${FULL_IMAGE}"
    echo "Also tagging as: ${DOCKERHUB_USER}/${IMAGE_NAME}:${DATE_TAG}"
    echo "Platforms: linux/amd64, linux/arm64"

    # Create buildx builder if it doesn't exist
    docker buildx create --name multiarch --use 2> /dev/null || docker buildx use multiarch

    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        -t "${FULL_IMAGE}" \
        -t "${DOCKERHUB_USER}/${IMAGE_NAME}:${DATE_TAG}" \
        -f "${DOCKERFILE}" \
        --push \
        .

    echo ""
    echo "Multi-arch build and push complete!"
    echo "Tags pushed: latest, ${DATE_TAG}"
    echo "Image available at: https://hub.docker.com/r/${DOCKERHUB_USER}/${IMAGE_NAME}"
else
    # Local build only (current architecture)
    echo "Building image for local arch: ${FULL_IMAGE}"

    docker build \
        -t "${FULL_IMAGE}" \
        -f "${DOCKERFILE}" \
        .

    echo "Build complete: ${FULL_IMAGE}"
    echo ""
    echo "To build multi-arch and push to Docker Hub, run:"
    if [[ "$IMAGE_VARIANT" == "default" ]]; then
        echo "  ./ci/build-image.sh --push"
    else
        echo "  ./ci/build-image.sh --image ${IMAGE_VARIANT} --push"
    fi
fi
