#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
tile_convert.py - Convert a PNG tileset to CPC+ Mode 0 tile binary.

Input:  A PNG image containing tiles arranged in a grid.
        The image must use a palette already quantised to <= 16 colours.
        Tiles are 8x8 pixels each.

Output: A .bin file:
  Bytes 0-31  : ASIC palette (16 x uint16_t LE, format 0x0GRB)
  Bytes 32+   : Tile data, one tile per 32 bytes (4 bytes/row x 8 rows)
                Tiles are read left-to-right, top-to-bottom from the tileset.

Usage:
  python3 tile_convert.py input.png output.bin [--cols N]

  --cols N  : number of tile columns in the tileset image (default: auto = image_width // 8)

Requires: Pillow  (pip install Pillow)
"""

import sys
import argparse
import struct
from PIL import Image

TILE_W = 8
TILE_H = 8
BYTES_PER_ROW = TILE_W // 2   # Mode 0: 2 pixels per byte = 4 bytes per row
BYTES_PER_TILE = BYTES_PER_ROW * TILE_H  # 32


def rgb_to_asic(r, g, b):
    r4 = min(15, (r + 8) >> 4)
    g4 = min(15, (g + 8) >> 4)
    b4 = min(15, (b + 8) >> 4)
    return (g4 << 8) | (r4 << 4) | b4


def encode_mode0_byte(p0, p1):
    b = 0
    for i in range(4):
        b |= ((p0 >> i) & 1) << (7 - i * 2)
        b |= ((p1 >> i) & 1) << (6 - i * 2)
    return b


def convert(input_path, output_path, cols_override):
    img = Image.open(input_path).convert('RGB')
    W, H = img.size

    tile_cols = cols_override if cols_override else W // TILE_W
    tile_rows = H // TILE_H
    n_tiles = tile_cols * tile_rows

    print(f"Tileset: {W}x{H} px = {tile_cols}x{tile_rows} tiles = {n_tiles} tiles total")

    # Quantise to 16 colours across the whole tileset
    q = img.quantize(colors=16, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.NONE)
    q = q.convert('P')
    palette_raw = q.getpalette()
    index_data = list(q.getdata())  # flat, row-major

    # Remap palette indices to a compact 0..15 range
    used = sorted(set(index_data))
    remap = {old: new for new, old in enumerate(used)}
    index_data = [remap[i] for i in index_data]

    colours = []
    for i in used:
        r, g, b = palette_raw[i * 3], palette_raw[i * 3 + 1], palette_raw[i * 3 + 2]
        colours.append((r, g, b))
    while len(colours) < 16:
        colours.append((0, 0, 0))

    asic_palette = [rgb_to_asic(r, g, b) for r, g, b in colours]
    palette_bytes = b''.join(struct.pack('<H', c) for c in asic_palette)

    # Encode tiles
    tile_data = bytearray()
    for ty in range(tile_rows):
        for tx in range(tile_cols):
            # Extract 8x8 tile at pixel (tx*8, ty*8)
            px0 = tx * TILE_W
            py0 = ty * TILE_H
            for row in range(TILE_H):
                y = py0 + row
                for col in range(0, TILE_W, 2):
                    x = px0 + col
                    p0 = index_data[y * W + x]
                    p1 = index_data[y * W + x + 1]
                    tile_data.append(encode_mode0_byte(p0, p1))

    with open(output_path, 'wb') as f:
        f.write(palette_bytes)
        f.write(tile_data)

    total = len(palette_bytes) + len(tile_data)
    print(f"  Palette: {len(palette_bytes)} bytes, Tiles: {len(tile_data)} bytes ({n_tiles} x {BYTES_PER_TILE}), Total: {total} bytes")
    print(f"  Colours used ({len(used)}):")
    for i, (asic, (r, g, b)) in enumerate(zip(asic_palette[:len(used)], colours[:len(used)])):
        print(f"    pen {i:2d}: RGB({r:3d},{g:3d},{b:3d}) -> ASIC 0x{asic:04X}")


def main():
    parser = argparse.ArgumentParser(description='Convert PNG tileset to CPC+ Mode 0 tile binary')
    parser.add_argument('input',  help='Input PNG tileset')
    parser.add_argument('output', help='Output .bin file')
    parser.add_argument('--cols', type=int, default=0,
                        help='Number of tile columns (default: image_width // 8)')
    args = parser.parse_args()
    convert(args.input, args.output, args.cols if args.cols else None)


if __name__ == '__main__':
    main()
