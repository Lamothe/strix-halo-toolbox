#!/bin/bash

# ==================================================================================================
# cleanup.sh - Teardown environment and reset repository state
#
# RUN THIS OUTSIDE THE CONTAINER!
# ==================================================================================================

CONTAINER_NAME=${1:-rocm-7.2.1}

echo "Destroying container $CONTAINER_NAME..."
toolbox rm -f "$CONTAINER_NAME"

echo "Cleaning root directory (keeping wheelhouse)..."
git clean -xdf -e wheelhouse/

echo "Cleaning submodule build artefacts..."
git submodule foreach --recursive git clean -xdf

echo "Cleanup complete!"