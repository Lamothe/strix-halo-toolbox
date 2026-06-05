# TRELLIS.2 ROCm Documentation

## Overview
This document describes the TRELLIS.2 port to ROCm (AMD GPU) for the Strix Halo toolbox.

---

## Issue: Garbled Textures in GLB Export

The `example.py` script produces **completely garbled textures** (correct geometry, garbage texture). The warp-level sync fixes in nvdiffrast did NOT resolve this issue.

### What Works
- 3D mesh generation ✅
- UV unwrapping ✅
- Mesh topology ✅
- nvdiffrast triangle rasterization test ✅

### What's Broken
- Texture baking in `o_voxel.postprocess.to_glb()` — produces fragmented, noisy texture output

---

## Texture Baking Pipeline Analysis

The `to_glb()` function uses this pipeline for texture baking:

```
1. UV rasterization: dr.rasterize(ctx, uvs_rast, faces, resolution=[2048, 2048])
   → Produces rast output mapping each texel to a triangle

2. Position interpolation: dr.interpolate(out_vertices, rast, faces)
   → Interpolates 3D vertex positions per texel

3. Back-projection to original mesh: bvh.unsigned_distance(valid_pos, return_uvw=True)
   → Maps simplified mesh positions back to original high-res mesh

4. Volume sampling: grid_sample_3d(attr_volume, grid=positions)
   → Samples color/material attributes from the 3D voxel volume

5. Post-processing: cv2.inpaint()
   → Fills UV seams with OpenCV inpainting
```

**The geometry is correct** (UVs unwrap properly, mesh topology is fine), but the **texture sampling produces garbage** (fragmented letters, random noise patterns).

### Likely Culprits (In Order of Suspicion)

| # | Suspect | Why |
|---|---------|-----|
| 1 | `grid_sample_3d` from flex_gemm | Trilinear volume sampling is a custom triton kernel — most likely source of garbage output |
| 2 | `dr.interpolate` for UV→position mapping | The triangle test doesn't exercise the UV-space rasterization path used by to_glb() |
| 3 | `dr.texture` with mipmapping | Used by MeshRenderer/PbrMeshRenderer, not by to_glb() directly |
| 4 | UV rasterization in UV space | `uvs_rast = out_uvs * 2 - 1` converts UVs to NDC — could have coordinate issues |

---

## Technical Details

### Architecture Differences
| Component | NVIDIA (CUDA) | AMD (ROCm) |
|-----------|---------------|------------|
| Warp size | 32 lanes | 64 lanes |
| `__ballot` | Returns 32-bit | Returns 64-bit |
| `__ballot_sync` | Native warp sync | Requires sub-wave handling |

### nvdiffrast Warp-Level Fixes (Applied, Not Root Cause)
All five warp-level sync bugs were fixed in nvdiffrast. The triangle test passes, but the texture corruption persists, indicating the issue is **downstream of core rasterization**.

See `nvdiffrast.md` for details.

---

## References
- nvdiffrast ROCm bugs and fixes: `nvdiffrast.md`
- TRELLIS.2 main repo: https://github.com/microsoft/TRELLIS.2
- o-voxel postprocess: `TRELLIS.2_rocm/o-voxel/o_voxel/postprocess.py`
- flex_gemm grid_sample: `FlexGEMM_rocm/flex_gemm/ops/grid_sample/`
- ROCm documentation: https://rocm.docs.amd.com/

---

## Debugging Instructions

### Step 1: Isolate the broken component
Test each stage of the texture baking pipeline independently:
1. Verify UV rasterization produces correct rast output
2. Verify `dr.interpolate` produces correct 3D positions per texel
3. Verify `grid_sample_3d` produces correct attribute values from known positions
4. Verify the back-projection from simplified mesh to original mesh

### Step 2: Focus on flex_gemm grid_sample_3d
The `grid_sample_3d` operation is the most likely culprit — it's a custom triton kernel for trilinear volume sampling, and the garbage pattern (fragmented noise) is consistent with incorrect volume sampling.

### Step 3: Test with PyTorch fallback
Compare `flex_gemm.grid_sample_3d()` output against `torch.nn.functional.grid_sample()` on the same inputs to identify discrepancies.

### Important Rules
- Always verify fixes with the actual TRELLIS.2 output, not just unit tests
- If a fix doesn't improve the texture output, immediately revert
- Document all findings in this file
