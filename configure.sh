#!/bin/bash

# ==================================================================================================
# configure.sh - Configure venv and environment variables for TRELLIS.2 on the Strix Halo.
#
# THIS NEEDS TO BE RUN INSIDE THE CONTAINER!!!
# ==================================================================================================

if [ ! -f ".venv/bin/activate" ]; then
    echo "Creating virtual environment"
    python3.12 -m venv .venv
fi

source .venv/bin/activate

export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH
export TORCH_ROCM_ARCH_LIST="gfx1151"
export PYTORCH_ROCM_ARCH="gfx1151"
export ROCM_HOME=/opt/rocm
export HIP_PATH=/opt/rocm
export FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE"
export PYTORCH_ALLOC_CONF="expandable_segments:True"
export PYTHONPATH=$(pwd)/TRELLIS.2/o-voxel
export CXX=/opt/rocm/bin/hipcc
export CC=/opt/rocm/bin/hipcc
export CFLAGS="-fcf-protection=none -Wno-narrowing"
export CXXFLAGS="-fcf-protection=none -Wno-narrowing"
export HSA_XNACK=1