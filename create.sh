#!/bin/bash

# ==================================================================================================
# create.sh - Create a container for TRELLIS.2 on the Strix Halo.
# ==================================================================================================

CONTAINER_NAME=${1:-rocm-7.2.1}

toolbox create "$CONTAINER_NAME" \
  --image localhost/strix-halo-toolbox:latest \
  -- --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render --group-add sudo --security-opt seccomp=unconfined >/dev/null 2>&1

echo "Now enter the container with ./enter.sh $CONTAINER_NAME"

