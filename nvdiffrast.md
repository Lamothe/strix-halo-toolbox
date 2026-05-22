# nvdiffrast ROCm Port Documentation

## Overview
This document describes the nvdiffrast port to ROCm (AMD GPU) for the Strix Halo toolbox.

## Summary
Two critical bugs were discovered and fixed in the nvdiffrast ROCm port:

1. **`__ballot_sync` macro truncation** (antialiasing): Improper handling of 64-lane wavefronts on AMD GPUs, where a 64-bit mask from `__ballot()` was truncated to 32-bit without accounting for sub-wave boundaries. Fixed with `WAVE32_BALLOT` macro.

2. **Spurious -128 NDC offset** (rasterization): The ROCm port had a `-128.0f` pixel coordinate offset in the forward and gradient kernels that doesn't exist in the original CUDA code. This shifted all NDC coordinates by -1 in both axes, causing completely wrong barycentric weight calculations. Fixed by removing the offset to match the original CUDA implementation.

Both fixes are verified by the test harness (`samples/torch/test_triangle_baseline.py`).

## Key Discoveries

### Critical Bug: `__ballot_sync` Macro Truncation
The nvdiffrast ROCm port had a critical bug in the `__ballot_sync` macro that caused incorrect behavior on AMD GPUs with 64-lane wavefronts (RDNA architecture). This bug manifested as "patchy" texture output in TRELLIS.2 examples using nvdiffrast for rendering.

### Problem
The nvdiffrast ROCm port had a critical bug in the `__ballot_sync` macro that caused incorrect behavior on AMD GPUs with 64-lane wavefronts (RDNA architecture).

**Original (Buggy) Implementation:**
```cpp
#define __ballot_sync(mask, predicate) __ballot(predicate)
```

This implementation:
1. Ignores the `mask` argument (which CUDA's `__ballot_sync` uses to filter participating lanes)
2. Returns a 64-bit mask from `__ballot()` but stores it in a 32-bit `unsigned int`, truncating the upper 32 bits

### Root Cause
- **CUDA**: `__ballot_sync(mask, predicate)` returns a 32-bit mask for a 32-lane warp
- **ROCm (AMD)**: `__ballot(predicate)` returns a 64-bit mask for a 64-lane wavefront

When the 64-bit mask was truncated to 32-bit:
- Lanes 0-31: Got the lower 32 bits (correct)
- Lanes 32-63: Also got the lower 32 bits (WRONG - should get upper 32 bits)

This caused incorrect warp-level coordination in the antialiasing kernel, resulting in "patchy" texture output.

### Solution
The fix properly extracts the 32-bit mask for each 32-lane sub-wave using the `WAVE32_BALLOT` macro:

```cpp
// Extract 32-bit mask for current sub-wave based on lane ID
#ifndef WAVE32_BALLOT
  #define WAVE32_BALLOT(pred) ((uint32_t)(__ballot(pred) >> ((__lane_id() >> 5) << 5)))
#endif
#define __ballot_sync(mask, predicate) WAVE32_BALLOT(predicate)
```

**How it works:**
- `(__lane_id() >> 5) << 5` computes the sub-wave index:
  - Lane 0-31: shift = 0 (lower 32 bits)
  - Lane 32-63: shift = 32 (upper 32 bits)
- The ballot result is shifted right to align the correct 32-bit chunk
- Cast to `uint32_t` extracts the result

### Files Modified
- `nvdiffrast_rocm/csrc/common/antialias.hip`: Fixed `__ballot_sync` macro definition

### Verification
All tests pass successfully:
- Basic triangle rasterization: ✓
- Attribute interpolation: ✓
- Rasterization gradients: ✓
- Antialiasing: ✓

---

### Critical Bug #2: Spurious -128 NDC Offset in Rasterization Kernel

Discovered by comparing `nvdiffrast_rocm/csrc/common/rasterize.hip` against the original CUDA source at https://github.com/NVlabs/nvdiffrast/blob/master/csrc/common/rasterize.cu

**Problem:**
The ROCm port had a spurious `-128.0f` pixel coordinate offset in both the forward shader kernel and the gradient kernel that does NOT exist in the original CUDA code.

**Original CUDA (correct):**
```cpp
float fx = p.xs * (float)px + p.xo;
float fy = p.ys * (float)py + p.yo;
```

**ROCm port (wrong):**
```cpp
// Un-bias pixel coordinates by viewport offset (2048 subpixel units = 128 pixels)
// BEFORE NDC conversion to match the fine rasterizer's shifted coordinate space.
float fx = p.xs * ((float)px - 128.0f) + p.xo;
float fy = p.ys * ((float)py - 128.0f) + p.yo;
```

This offset shifts all NDC pixel coordinates by approximately -1.0 in both axes. For a 256×256 image:
- CUDA: px=0 → fx ≈ -1.0, px=255 → fx ≈ +1.0 (correct full NDC range)
- ROCm: px=0 → fx ≈ -2.0, px=255 → fx ≈ 0.0 (shifted by -1, only half the range visible)

**Impact:**
The barycentric coordinate calculations were completely wrong:
- At triangle center: u=1.0, v=0.0 (vertex 0 gets 100% weight everywhere)
- Expected: u≈0.33, v≈0.33, w≈0.34 (equal weights)
- This caused the triangle to render as almost entirely RED (vertex 0's color) instead of a proper RGB gradient

**Test baseline (before fix):**
- MSE on triangle pixels: 0.2617
- Max diff: 0.996
- Barycentric at center: u=1.0000, v=0.0000, w=0.0000

**Solution:**
Removed the spurious `-128.0f` offset from both the forward kernel (line 72-73) and gradient kernel (line 189-190) in `rasterize.hip`. Also removed the incorrect comment.

**Files Modified:**
- `nvdiffrast_rocm/csrc/common/rasterize.hip`: Removed `-128.0f` offset from forward and gradient kernels

### Testing Methodology
The fix was developed using a strict TDD loop:

1. **Test Harness**: Created minimal Python test using `samples/torch` to establish MSE/max diff between ROCm and CUDA baseline
2. **One-at-a-time fixes**: Made single targeted modifications to HIP kernel code
3. **Immediate rollback**: If fix didn't reduce diff to 0.0, reverted with `git restore`
4. **Verification**: Recompiled and tested after each change

### Files Modified
- `nvdiffrast_rocm/csrc/common/antialias.hip`: Fixed `__ballot_sync` macro using `WAVE32_BALLOT`
- `nvdiffrast_rocm/csrc/common/common.h`: Contains coalesced atomics macros (no changes needed)

---

## Additional Notes

### Warp Size Differences
| GPU Vendor | Warp Size | ballot return type |
|------------|-----------|-------------------|
| NVIDIA     | 32        | 32-bit            |
| AMD (ROCm) | 64        | 64-bit            |

### HIP-Specific Macros Used
- `__ballot(predicate)`: Returns 64-bit mask of lanes with predicate true
- `__lane_id()`: Returns lane ID within wavefront (0-63)
- `__all(pred)`: Returns true if all lanes have predicate true
- `__any(pred)`: Returns true if any lane has predicate true

### CUDA Compatibility
The fix maintains compatibility with the original CUDA code by:
1. Preserving the `__ballot_sync(mask, predicate)` function signature
2. Returning a 32-bit mask (truncated from 64-bit for current sub-wave)
3. The mask argument is ignored in HIP (same behavior as original buggy code)

### Coalesced Atomics
The HIP implementation uses a simplified coalesced atomics system:
- CUDA: Uses `__match_any_sync(mask, group)` for lane selection
- HIP: Uses simpler `caAtomicAdd` without lane matching (empty `CA_SET_GROUP_MASK` macro)

This is acceptable because the HIP code path doesn't rely on complex lane-level coordination.

---

## Debugging Instructions (For Future Work)

When debugging nvdiffrast ROCm kernel issues, follow this strict Test-Driven Development (TDD) loop:

### THE HARNESS: Write a minimal Python test
1. Use the `nvdiffrast_rocm/samples/torch/` directory to create minimal test scripts
2. Run the test to establish the mathematical pixel difference (MSE/max diff) between the broken ROCm output and the known-good CUDA baseline
3. The test should output numerical metrics to verify the fix:
   ```python
   import torch
   import nvdiffrast.torch as dr
   
   # Run rasterization and compare with expected values
   # Compute MSE = mean((roc - cuda)^2) or max diff = max(|roc - cuda|)
   # Target: diff == 0.0 for perfect match
   ```

### THE GUESS: Make ONE single, highly targeted modification
1. Edit ONLY the C++/HIP kernel code (e.g., fix a specific mathematical operation or indexing error)
2. Keep changes minimal and surgical - one change per iteration
3. Document the change clearly with comments explaining the fix

### THE VERIFICATION: Recompile and test
1. Rebuild the ROCm port: `cd nvdiffrast_rocm && python setup.py build_ext --inplace`
2. Run the test harness again
3. Compare the numerical results with the CUDA baseline

### THE ROLLBACK (CRITICAL): If fix doesn't work, REVERT immediately
If the code fails to compile OR if the mathematical pixel difference does NOT improve to 0.0:
```bash
cd /home/michael/Projects/strix-halo-toolbox
git -C nvdiffrast_rocm restore <filename>
```
You are STRICTLY FORBIDDEN from stacking multiple guesses on top of broken code.

### THE LOOP: Repeat until perfect
1. Go back to THE GUESS with a new hypothesis
2. Repeat steps 2-4 until the test harness proves ROCm output matches CUDA baseline (diff == 0.0)
3. Only stop when you have a PROVEN, mathematically verified fix
4. Document the final fix in this file

### Important Rules
- Do not explain intermediate failures
- Only present findings when you have a proven fix with final test output confirming success
- The `git restore` command must be used immediately on any failing iteration
- Do not stack multiple changes - make one targeted fix per iteration
- Always verify with numerical comparison against CUDA baseline
- When `example.py` produces patchy textures but `example_texturing.py` produces perfect textures, the issue is almost certainly in nvdiffrast's warp-level coordination (antialiasing kernel using `__ballot_sync`)