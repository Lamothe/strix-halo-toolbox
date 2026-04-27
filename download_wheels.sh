#!/bin/bash

# ==================================================================================================
# download_wheels.sh - Download ROCm PyTorch wheels to a local directory.
# ==================================================================================================

WHEEL_DIR="./wheelhouse"

mkdir -p "$WHEEL_DIR"

echo "Downloading PyTorch wheels to $WHEEL_DIR..."

wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.2/torch-2.9.1+rocm7.2.2.lw.git127a149a-cp312-cp312-linux_x86_64.whl
wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.2/torchaudio-2.9.0+rocm7.2.2.gite3c6ee2b-cp312-cp312-linux_x86_64.whl
wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.2/torchvision-0.24.0+rocm7.2.2.gitb919bd0c-cp312-cp312-linux_x86_64.whl
wget -nc -P "$WHEEL_DIR" https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2.2/triton-3.5.1+rocm7.2.2.gita272dfa8-cp312-cp312-linux_x86_64.whl

echo "Download complete!"
