#!/bin/bash

# ==================================================================================================
# enter.sh - Enter the container and automatically apply configurations.
# ==================================================================================================

CONTAINER_NAME=${1:-rocm-7.2.2}

# This enters the container, sources configure.sh, and drops you into a persistent bash prompt
toolbox run --container "$CONTAINER_NAME" bash -c "source configure.sh && exec bash"

