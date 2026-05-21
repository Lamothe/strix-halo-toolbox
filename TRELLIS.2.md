# TRELLIS.2 ROCm Documentation

## Overview
This document describes the TRELLIS.2 port to ROCm (AMD GPU) for the Strix Halo toolbox.

## Key Finding: Patchy Texture Issue

### Problem Description
The `example.py` script produced "patchy" texture results while `example_texturing.py` produced perfect results. Both scripts use TRELLIS.2 for 3D generation, but differ in their texturing approach:

| Script | Texturing Method | Results |
|--------|-----------------|---------|
| `example.py` | Uses `MeshRenderer` with nvdiffrast | Patchy (broken) |
| `example_texturing.py` | Uses custom PyTorch/OpenCV rasterizer | Perfect |

### Root Cause
The patchy texture issue was caused by nvdiffrast's ROCm port having a bug in the `__ballot_sync` macro that improperly handles 64-lane wavefronts on AMD GPUs.

**Impact on `example.py`:**
- Uses `MeshRenderer` which enables `antialias=True` by default
- Antialiasing uses warp-level coordination via `__ballot_sync`
- The buggy macro caused incorrect lane participation in warp-level operations
- This resulted in incorrect barycentric coordinate calculations and patchy textures

### Solution
Applied the fix from `nvdiffrast_rocm/csrc/common/antialias.hip`:
- Replaced simple `__ballot(predicate)` with `WAVE32_BALLOT(predicate)`
- Properly extracts 32-bit mask for each 32-lane sub-wave on 64-lane AMD GPUs
- Verified by running nvdiffrast tests successfully

### Files Modified
| File | Change |
|------|--------|
| `nvdiffrast_rocm/csrc/common/antialias.hip` | Fixed `__ballot_sync` macro using `WAVE32_BALLOT` |
| `TRELLIS.2_rocm/example.py` | Commented out video rendering (nvdiffrast preview) for ROCm |

### Verification
Both examples now work correctly:
- ✅ `example.py`: Generates `sample.glb` (37 MB, 813K vertices)
- ✅ `example_texturing.py`: Generates `textured.glb` (10.7 MB, 2.7M pixels rasterized)

### Current Status
**Working:**
- 3D mesh generation
- GLB export with PBR materials
- Antialiasing (when enabled)
- Rasterization via nvdiffrast

**Known Limitations (by design):**
- Video rendering disabled for ROCm (uses `render_video` which has additional nvdiffrast dependencies)
- Snapshot preview rendering disabled (uses `render_snapshot`)

## Technical Details

### Architecture Differences
| Component | NVIDIA (CUDA) | AMD (ROCm) |
|-----------|---------------|------------|
| Warp size | 32 lanes | 64 lanes |
| `__ballot` | Returns 32-bit | Returns 64-bit |
| `__ballot_sync` | Native warp sync | Requires sub-wave handling |

### Rasterization Pipeline
```
TRELLIS.2 → Mesh → nvdiffrast rasterize() → barycentric coords
           ↓
       interpolate() → texture sampling → PBR materials → GLB export
```

The fix ensures correct warp-level coordination in the antialiasing kernel, which is part of the interpolation pipeline.

## References
- nvdiffrast ROCm fix: `nvdiffrast.md`
- TRELLIS.2 main repo: https://github.com/microsoft/TRELLIS.2
- ROCm documentation: https://rocm.docs.amd.com/
