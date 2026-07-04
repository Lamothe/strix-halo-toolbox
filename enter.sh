#!/bin/bash

# ==================================================================================================
# enter.sh - Enter the container.
# Run '. configure.sh' after entering to activate the venv and set environment variables.
# ==================================================================================================

CONTAINER_NAME=${1:-rocm-7.2.4}

toolbox run --container "$CONTAINER_NAME" bash
