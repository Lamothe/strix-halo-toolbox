# nvdiffrast ROCm Port Documentation

## Overview
This document describes the nvdiffrast port to ROCm (AMD GPU) for the Strix Halo toolbox.

## Summary
Five warp-level sync bugs were discovered and fixed in the nvdiffrast ROCm port. **However, these fixes did not resolve the TRELLIS.2 texture corruption issue.** The triangle rasterization test passes (MSE < 0.001), but the actual texture sampling path used by TRELLIS.2 still produces garbled output.

### Warp-Level Sync Bugs (All Fixed, Not the Root Cause)

1. **`__ballot_sync` macro truncation** (antialiasing): Fixed with `WAVE32_BALLOT` macro. ✅
2. **Spurious -128 NDC offset** (rasterization): Fixed by removing the offset. ✅
3. **hipraster core rasterizer — hardcoded 32-lane warp semantics**: Fixed with `myLane = __lane_id() & 31` and wave32-scoped shuffles. ✅
4. **`__all_sync` in interpolate.hip — full wavefront scope**: Fixed with `__all_sync_32()`. ✅
5. **`__ballot_sync` in interpolate.hip and texture_kernel.hip**: Fixed with `WAVE32_BALLOT`. ✅

### Actual Issue (Still Under Investigation)

The warp-level fixes verified against the triangle test, but TRELLIS.2 `example.py` still produces **completely garbled textures** (correct geometry, garbage texture). This indicates the issue is **not in the core rasterizer** but in a downstream sampling path.

**Key observation:** The `to_glb()` function uses a two-stage texture baking pipeline:
1. UV-space rasterization: `dr.rasterize(ctx, uvs_rast, faces, resolution)` — rasterize UV coordinates as NDC vertices
2. Position interpolation: `dr.interpolate(out_vertices, rast, faces)` — interpolate 3D positions per texel
3. Volume sampling: `grid_sample_3d(attr_volume, grid=positions)` — sample attributes from the 3D voxel volume

**The geometry is correct** (UV unwrapping works, mesh topology is fine), but the **texture sampling produces garbage** (fragmented letters, random noise). The issue is likely in either:
- The `dr.interpolate` path for UV→position mapping (not tested by the triangle test)
- The `grid_sample_3d` operation from flex_gemm (trilinear volume sampling)
- The `dr.texture` with mipmapping path (not exercised by the basic triangle test)

---

## Fixed Warp-Level Bugs

### Critical Bug #1: `__ballot_sync` Macro Truncation (antialias.hip)

**Status: FIXED (but not root cause of texture corruption)**

**Original (Buggy):**
```cpp
#define __ballot_sync(mask, predicate) __ballot(predicate)
```

**Fixed:**
```cpp
#ifndef WAVE32_BALLOT
  #define WAVE32_BALLOT(pred) ((uint32_t)(__ballot(pred) >> ((__lane_id() >> 5) << 5)))
#endif
#define __ballot_sync(mask, predicate) WAVE32_BALLOT(predicate)
```

**Files Modified:** `nvdiffrast_rocm/csrc/common/antialias.hip`

---

### Critical Bug #2: Spurious -128 NDC Offset (rasterize.hip)

**Status: FIXED (but not root cause of texture corruption)**

Removed spurious `-128.0f` pixel coordinate offset from forward and gradient kernels.

**Test baseline (before fix):**
- MSE on triangle pixels: 0.2617
- Max diff: 0.996
- Barycentric at center: u=1.0000, v=0.0000, w=0.0000

**Files Modified:** `nvdiffrast_rocm/csrc/common/rasterize.hip`

---

### Critical Bug #3: hipraster Core Rasterizer — Hardcoded 32-Lane Warp Semantics

**Status: FIXED (but not root cause of texture corruption)**

Changed all `__launch_bounds__` from `* 32` to `* 64`, added `myLane = __lane_id() & 31`, and replaced all `__shfl`/`__shfl_up`/`__shfl_down` with wave32-scoped variants.

**Files Modified:**
- `csrc/common/hipraster/impl/RasterImpl_kernel.hip`
- `csrc/common/hipraster/impl/BinRaster.inl`
- `csrc/common/hipraster/impl/CoarseRaster.inl`
- `csrc/common/hipraster/impl/FineRaster.inl`
- `csrc/common/hipraster/impl/Util.inl`

---

### Critical Bug #4: `__all_sync` in interpolate.hip — Full Wavefront Scope

**Status: FIXED (but not root cause of texture corruption)**

Added `__all_sync_32()` helper that scopes to 32-lane sub-wave instead of full 64-lane wavefront.

**Files Modified:** `csrc/common/interpolate.hip`

---

### Critical Bug #5: `__ballot_sync` in interpolate.hip and texture_kernel.hip

**Status: FIXED (but not root cause of texture corruption)**

Applied `WAVE32_BALLOT` to `interpolate.hip`, `texture_kernel.hip`, and `rasterize.hip`.

**Files Modified:**
- `csrc/common/interpolate.hip`
- `csrc/common/texture_kernel.hip`
- `csrc/common/rasterize.hip`

---

## Additional Notes

### Warp Size Differences
| GPU Vendor | Warp Size | ballot return type |
|------------|-----------|-------------------|
| NVIDIA     | 32        | 32-bit            |
| AMD (ROCm) | 64        | 64-bit            |

### CUDA Compatibility
The fix maintains compatibility with the original CUDA code by:
1. Preserving the `__ballot_sync(mask, predicate)` function signature
2. Returning a 32-bit mask (truncated from 64-bit for current sub-wave)

---

## Debugging Instructions (For Future Work)

When debugging nvdiffrast ROCm kernel issues, follow this strict Test-Driven Development (TDD) loop:

### THE HARNESS: Write a minimal Python test
1. Use the `nvdiffrast_rocm/samples/torch/` directory to create minimal test scripts
2. Run the test to establish the mathematical pixel difference (MSE/max diff) between the broken ROCm output and the known-good CUDA baseline
3. The test should output numerical metrics to verify the fix

### THE GUESS: Make ONE single, highly targeted modification
1. Edit ONLY the C++/HIP kernel code
2. Keep changes minimal and surgical - one change per iteration

### THE VERIFICATION: Recompile and test
1. Rebuild: `cd nvdiffrast_rocm && python setup.py build_ext --inplace`
2. Run the test harness again
3. Compare the numerical results with the CUDA baseline

### THE ROLLBACK (CRITICAL): If fix doesn't work, REVERT immediately
```bash
cd /home/michael/Projects/strix-halo-toolbox
git -C nvdiffrast_rocm restore <filename>
```

### Important Rules
- Do not explain intermediate failures
- Only present findings when you have a proven fix with final test output confirming success
- The `git restore` command must be used immediately on any failing iteration
- Do not stack multiple changes - make one targeted fix per iteration

---

## Fix Priority

| Bug | Status | Impact |
|-----|--------|--------|
| #1-5: Warp-level sync | ✅ FIXED | Verified by triangle test, but NOT the root cause of TRELLIS.2 texture corruption |
| Texture sampling path | 🔍 UNDER INVESTIGATION | The actual source of the garbled texture output |
