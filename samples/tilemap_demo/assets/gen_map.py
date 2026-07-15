#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""Generate a simple 20x25 test map."""
import sys

W, H = 20, 25
data = bytearray(W * H)

for row in range(H):
    for col in range(W):
        # Border uses tile 1 (light grey), interior cycles through tiles 2-15
        if row == 0 or row == H-1 or col == 0 or col == W-1:
            data[row * W + col] = 1   # border tile
        else:
            data[row * W + col] = (row + col) % 14 + 2  # interior pattern

out = sys.argv[1] if len(sys.argv) > 1 else 'map.bin'
open(out, 'wb').write(data)
print(f"Generated {W}x{H} map -> {out} ({len(data)} bytes)")
