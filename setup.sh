#!/bin/bash

# ==================================================================================================
# setup.sh - Setup for TRELLIS.2 on the Strix Halo.
#
# THIS NEEDS TO BE RUN INSIDE THE CONTAINER!!!
# ==================================================================================================

# Bail on error
set -e

echo "Pulling submodules"
git submodule update --init --recursive -q

pip install --upgrade pip setuptools wheel

# Ensure previous PyTorch installs are removed
pip uninstall triton torch torchvision torchaudio -y 

echo "Installing PyTorch from local wheelhouse..."
pip install ./wheelhouse/*.whl

export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH

# Test install
python -c "import torch; print(f'ROCm available: {torch.cuda.is_available()}')"
python -c "import torch; x = torch.rand(5, 5).cuda(); print(x @ x); print('Math works')"

echo "Installing Python dependencies"
pip install ninja jupyter addict matplotlib plyfile open3d easydict trimesh zstandard opencv-python-headless imageio rembg onnxruntime-gpu kornia timm "transformers<4.47"
pip install utils3d --no-deps
pip install "git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8"
pip install imageio-ffmpeg gradio pyrender pyopengl "pyglet<2" opencv-python-headless eigen xatlas

echo "Installing Flash Attention 2 (ROCm)"
cd flash-attention/
pip install . --no-build-isolation
cd ..

echo "Installing FlexGEMM (ROCm)"
cd FlexGEMM_rocm
pip install . --no-build-isolation
cd ..

echo "Installing CuMesh (ROCm)"
cd CuMesh_rocm
pip install . --no-build-isolation
cd ..

echo "Installing nvdiffrast (ROCm)"
cd nvdiffrast_rocm
pip install . --no-build-isolation
cd ..

echo "Installing o-voxel"
cd TRELLIS.2_rocm/o-voxel
pip install . --no-build-isolation
cd ../..

echo "Installing ComfyUI Dependencies"
cd ComfyUI
pip install -r requirements.txt
cd ..

echo "Setup complete!"