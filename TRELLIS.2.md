# TRELLIS.2 ROCm Documentation

## Overview
This document describes the TRELLIS.2 port to ROCm (AMD GPU) for the Strix Halo toolbox.

## Summary
A debugging session was conducted to investigate a "patchy" texture issue in TRELLIS.2 ROCm. The issue was caused by nvdiffrast's ROCm port having a bug in the `__ballot_sync` macro. The fix involved modifying the macro to properly handle 64-lane wavefronts on AMD GPUs.

## Key Discoveries

## Issue: Patchy Texture in example.py vs Perfect Texture in example_texturing.py

The `example.py` script produced "patchy" texture results while `example_texturing.py` produced perfect results. Both scripts use TRELLIS.2 for 3D generation, but differ in their texturing approach:

| Script | Texturing Method | Results |
|--------|-----------------|---------|
| `example.py` | Uses `MeshRenderer` with nvdiffrast | Patchy (broken) |
| `example_texturing.py` | Uses custom PyTorch/OpenCV rasterizer | Perfect |

### Root Cause

**Root Cause:**
The patchy texture issue was caused by nvdiffrast's ROCm port having a bug in the `__ballot_sync` macro that improperly handles 64-lane wavefronts on AMD GPUs.

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

---

## Debugging Instructions (For Future Work)

When debugging TRELLIS.2 ROCm rendering issues, follow this workflow:

### Step 1: Determine if the issue is in nvdiffrast
- If `example.py` produces patchy textures but `example_texturing.py` produces perfect textures → the issue is almost certainly in nvdiffrast's warp-level coordination (antialiasing kernel using `__ballot_sync`)
- If both examples are affected → the issue may be in the 3D generation or post-processing pipeline

### Step 2: Check nvdiffrast tests first
Before modifying TRELLIS.2 code, verify nvdiffrast itself works correctly:
```bash
cd /home/michael/Projects/strix-halo-toolbox/nvdiffrast_rocm
python -c "import nvdiffrast.torch as dr; print('nvdiffrast imports successfully')"
```

### Step 3: Look at the nvdiffrast.md file
The `nvdiffrast.md` file in this repository contains:
1. Known issues and their solutions
2. The strict TDD loop for kernel debugging
3. Instructions for writing test harnesses
4. Verification methodology

### Step 4: If nvdiffrast is confirmed buggy, use the TDD loop
See `nvdiffrast.md` for the detailed Test-Driven Development loop:
1. Write minimal Python test harness
2. Make ONE targeted fix to HIP kernel code
3. Recompile and verify with numerical comparison
4. If fix fails, immediately `git restore` the change
5. Repeat until proven fix (diff == 0.0)

### Important Rules
- Do not modify TRELLIS.2 code to work around nvdiffrast bugs - fix nvdiffrast directly
- Always verify fixes with numerical comparison against CUDA baseline
- If a fix doesn't improve the numerical diff, immediately revert with `git -C nvdiffrast_rocm restore <filename>`
- Document all fixes in `nvdiffrast.md` with the final test output
