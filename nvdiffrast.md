# nvdiffrast ROCm Port Documentation

## Overview
This document describes the nvdiffrast port to ROCm (AMD GPU) for the Strix Halo toolbox.

## Key Finding: Warp Synchronization Bug on 64-Lane Wavefronts

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
