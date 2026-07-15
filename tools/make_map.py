#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
make_map.py - Combine tile binary (palette + tile gfx) with a map file.

Input:
  tile_bin  : output from tile_convert.py (32-byte palette + N*32 tile bytes)
  map_file  : raw map data (uint8_t array, row-major, map_w * map_h bytes)
              OR a Python expression file that generates it

Output:
  A single .bin: palette(32) + tile_gfx(N*32) + map_data

Usage:
  python3 make_map.py tiles.bin map.bin output.bin
"""

import sys

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} tiles.bin map.bin output.bin")
        sys.exit(1)

    tiles = open(sys.argv[1], 'rb').read()
    map_data = open(sys.argv[2], 'rb').read()
    out_path = sys.argv[3]

    combined = tiles + map_data
    with open(out_path, 'wb') as f:
        f.write(combined)

    print(f"Combined: {len(tiles)} (tiles) + {len(map_data)} (map) = {len(combined)} bytes -> {out_path}")


if __name__ == '__main__':
    main()
