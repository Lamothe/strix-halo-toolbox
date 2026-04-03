#!/bin/bash

# ==================================================================================================
# build.sh - Build the baseline image for the Strix Halo
# ==================================================================================================

echo "Building strix-halo-toolbox image..."

set -e

podman build \
  -t strix-halo-toolbox:rocm-7.2.1-fedora-43 \
  -t strix-halo-toolbox:latest \
  .

echo "Build complete! You can now run ./create.sh"

