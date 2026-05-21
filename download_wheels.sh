#!/bin/bash

# ==================================================================================================
# download_wheels.sh - Download ROCm PyTorch wheels to a local directory.
# ==================================================================================================

WHEEL_DIR="./wheelhouse"

mkdir -p "$WHEEL_DIR"

echo "Downloading PyTorch wheels to $WHEEL_DIR..."

wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.3/torch-2.9.1+rocm7.2.3.lw.gitebc02d69-cp312-cp312-linux_x86_64.whl
wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.3/torchvision-0.24.0+rocm7.2.3.gitb919bd0c-cp312-cp312-linux_x86_64.whl
wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.3/torchaudio-2.9.0+rocm7.2.3.gite3c6ee2b-cp312-cp312-linux_x86_64.whl
wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.3/triton-3.5.1+rocm7.2.3.gita272dfa8-cp312-cp312-linux_x86_64.whl

echo "Download complete!"
