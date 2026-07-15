#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
map_from_image.py — Convert a full map image into a deduplicated tileset + map.

The input image is a complete map rendered at tile resolution.
Each 8x8 pixel block is treated as one tile. Identical blocks are merged
into a single tile entry, producing a compact tileset and a tile-index map.

INPUT:
  map_image.png      Full map image. Width must be a multiple of tile size.
                     Height must be a multiple of tile size.

OPTIONS:
  --tile-size N      Tile size in pixels (default: 8)
  --colors N         Max palette colours (default: 16)
  --out FILE         Output asset .bin (default: asset.bin)
  --out-png FILE     Optional: save the reconstructed tileset PNG for inspection
  --out-csv FILE     Optional: save the map as plain CSV for use with Tiled

OUTPUT binary layout (same as tileset_import.py):
  Bytes   0-31       ASIC palette (16 x uint16_t LE, 0x0GRB)
  Bytes  32+         Tile graphics (N unique tiles x 32 bytes each)
  Bytes  32+N*32     Map data (map_w x map_h bytes, row-major, uint8_t tile IDs)

Requires: Pillow
"""

import sys
import argparse
import struct
from PIL import Image

TILE_W = TILE_H = 8
BYTES_PER_ROW  = TILE_W // 2
BYTES_PER_TILE = BYTES_PER_ROW * TILE_H   # 32


# ---------------------------------------------------------------------------
# Colour helpers (shared with tileset_import.py)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Core: quantise whole image, then deduplicate tiles
# ---------------------------------------------------------------------------

def process(img, n_colors, tile_size):
    W, H = img.size
    tw = tile_size
    th = tile_size
    map_w = W // tw
    map_h = H // th

    if W % tw or H % th:
        sys.exit(f"Image size {W}x{H} is not a multiple of tile size {tw}x{th}")

    print(f"Image: {W}x{H} px  →  map {map_w}×{map_h} tiles")

    # Quantise entire image to shared palette
    q = img.quantize(colors=n_colors, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.NONE).convert('P')
    raw_pal = q.getpalette()
    indices = list(q.getdata())

    # Build colour list from used indices
    used_palette = sorted(set(indices))
    remap = {old: new for new, old in enumerate(used_palette)}
    indices = [remap[i] for i in indices]

    colours = [(raw_pal[i*3], raw_pal[i*3+1], raw_pal[i*3+2]) for i in used_palette]
    while len(colours) < 16:
        colours.append((0, 0, 0))

    asic_palette = b''.join(struct.pack('<H', rgb_to_asic(r, g, b)) for r, g, b in colours)

    # Extract each tile as a tuple of pixel indices (hashable, for dedup)
    def get_tile_pixels(tx, ty):
        px0, py0 = tx * tw, ty * th
        pixels = []
        for row in range(th):
            y = py0 + row
            for col in range(tw):
                pixels.append(indices[y * W + px0 + col])
        return tuple(pixels)

    # Deduplicate
    tile_map = {}        # pixel_tuple -> tile_id
    tile_list = []       # ordered unique tiles (pixel tuples)
    map_data  = bytearray()

    for ty in range(map_h):
        for tx in range(map_w):
            pixels = get_tile_pixels(tx, ty)
            if pixels not in tile_map:
                tile_map[pixels] = len(tile_list)
                tile_list.append(pixels)
            map_data.append(tile_map[pixels])

    n_unique = len(tile_list)
    print(f"Unique tiles: {n_unique}  (from {map_w * map_h} total)")

    if n_unique > 255:
        print(f"WARNING: {n_unique} unique tiles — map uses uint8_t IDs, max 255.")

    # Encode tile graphics
    tile_bytes = bytearray()
    for pixels in tile_list:
        for row in range(th):
            for col in range(0, tw, 2):
                p0 = pixels[row * tw + col]
                p1 = pixels[row * tw + col + 1]
                tile_bytes.append(encode_mode0_byte(p0, p1))

    return asic_palette, bytes(tile_bytes), bytes(map_data), map_w, map_h, tile_list, colours, indices


def save_tileset_png(tile_list, colours, n_cols, path):
    """Save unique tiles as a PNG strip for inspection."""
    n = len(tile_list)
    rows = (n + n_cols - 1) // n_cols
    img = Image.new('P', (n_cols * TILE_W, rows * TILE_H))
    pal = []
    for r, g, b in colours:
        pal.extend([r, g, b])
    while len(pal) < 768:
        pal.extend([0, 0, 0])
    img.putpalette(pal)
    pixels = [0] * (n_cols * TILE_W * rows * TILE_H)
    for tid, tile_pixels in enumerate(tile_list):
        tx = (tid % n_cols) * TILE_W
        ty = (tid // n_cols) * TILE_H
        for row in range(TILE_H):
            for col in range(TILE_W):
                x = tx + col
                y = ty + row
                pixels[y * n_cols * TILE_W + x] = tile_pixels[row * TILE_W + col]
    img.putdata(pixels)
    img.save(path)
    print(f"Tileset PNG: {path}  ({n_cols} cols × {rows} rows = {n} tiles)")


def save_map_csv(map_data, map_w, path):
    lines = []
    for row in range(len(map_data) // map_w):
        lines.append(','.join(str(map_data[row * map_w + col]) for col in range(map_w)))
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"Map CSV: {path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(
        description='Convert a map image to deduplicated CPC+ tileset + map binary')
    p.add_argument('image',              help='Input map PNG')
    p.add_argument('--out',              default='asset.bin', help='Output asset .bin')
    p.add_argument('--out-png',          metavar='FILE',      help='Save tileset preview PNG')
    p.add_argument('--out-csv',          metavar='FILE',      help='Save map as CSV')
    p.add_argument('--tile-size',        type=int, default=8, help='Tile size in pixels (default 8)')
    p.add_argument('--colors',           type=int, default=16)
    p.add_argument('--tileset-cols',     type=int, default=16,
                   help='Columns in tileset preview PNG (default 16)')
    p.add_argument('--out-header',       metavar='FILE',
                   help='Emit a C header with ASSET_N_TILES, ASSET_MAP_W, ASSET_MAP_H')
    args = p.parse_args()

    img = Image.open(args.image).convert('RGB')

    asic_palette, tile_bytes, map_data, map_w, map_h, tile_list, colours, _ = \
        process(img, args.colors, args.tile_size)

    out = asic_palette + tile_bytes + map_data
    with open(args.out, 'wb') as f:
        f.write(out)

    n_tiles = len(tile_bytes) // BYTES_PER_TILE
    print(f"Output: palette=32B  tiles={n_tiles}×32={len(tile_bytes)}B  "
          f"map={map_w}×{map_h}={len(map_data)}B  total={len(out)}B → {args.out}")

    if args.out_png:
        save_tileset_png(tile_list, colours, args.tileset_cols, args.out_png)

    if args.out_csv:
        save_map_csv(map_data, map_w, args.out_csv)

    if args.out_header:
        n_tiles = len(tile_bytes) // BYTES_PER_TILE
        with open(args.out_header, 'w') as f:
            f.write(f'#ifndef ASSET_INFO_H\n#define ASSET_INFO_H\n')
            f.write(f'#define ASSET_N_TILES  {n_tiles}\n')
            f.write(f'#define ASSET_MAP_W    {map_w}\n')
            f.write(f'#define ASSET_MAP_H    {map_h}\n')
            f.write(f'#endif\n')
        print(f"Header: {args.out_header}  (N_TILES={n_tiles}, {map_w}x{map_h})")


if __name__ == '__main__':
    main()
