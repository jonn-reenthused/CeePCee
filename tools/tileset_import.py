#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
tileset_import.py — Import a tileset PNG + optional map and produce a CPC+ asset binary.

INPUT:
  tileset.png        Tileset image. Tiles are arranged in a grid, left-to-right,
                     top-to-bottom. Each tile is 8x8 pixels.
  [map source]       One of:
                       --map-csv  map.csv    Raw CSV (row per tile row, comma-separated tile IDs, 0-based)
                       --map-tiled map.tmx   Tiled .tmx XML export (CSV layer encoding)
                       --map-tiled map.csv   Tiled CSV export (File > Export As > CSV)
                     If no map is given, a blank 20x25 map (all tile 0) is generated.

OPTIONS:
  --tile-size N      Tile size in pixels (default: 8)
  --map-width  W     Map width  in tiles (default: 20)
  --map-height H     Map height in tiles (default: 25)
  --colors N         Max colours to quantise to (default: 16)
  --out FILE         Output asset .bin (default: asset.bin)

OUTPUT binary layout:
  Bytes   0-31    ASIC palette (16 x uint16_t LE, 0x0GRB)
  Bytes  32+      Tile graphics (N tiles x 32 bytes each)
  Bytes  32+N*32  Map data      (map_width x map_height bytes, row-major, uint8_t tile IDs)

Requires: Pillow, xml.etree (stdlib)
"""

import sys, argparse, struct, re, xml.etree.ElementTree as ET
from PIL import Image

TILE_W = TILE_H = 8
BYTES_PER_ROW   = TILE_W // 2      # Mode 0: 2 pixels/byte
BYTES_PER_TILE  = BYTES_PER_ROW * TILE_H  # 32


# ---------------------------------------------------------------------------
# Colour helpers
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
# Tileset encoding
# ---------------------------------------------------------------------------

def quantise(img, n_colors):
    """Quantise img to n_colors, return (index_array_WxH, palette_list_of_rgb)."""
    q = img.quantize(colors=n_colors, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.NONE).convert('P')
    raw_pal = q.getpalette()
    indices = list(q.getdata())
    used = sorted(set(indices))
    remap = {old: new for new, old in enumerate(used)}
    indices = [remap[i] for i in indices]
    colours = [(raw_pal[i*3], raw_pal[i*3+1], raw_pal[i*3+2]) for i in used]
    while len(colours) < 16:
        colours.append((0, 0, 0))
    return indices, img.width, colours


def encode_tileset(img, n_colors=16):
    """
    Returns (asic_palette_bytes, tile_data_bytes, tile_cols, tile_rows).
    """
    W, H = img.size
    tile_cols = W // TILE_W
    tile_rows = H // TILE_H

    indices, iw, colours = quantise(img, n_colors)

    asic_palette = b''.join(struct.pack('<H', rgb_to_asic(r, g, b)) for r, g, b in colours)

    tile_data = bytearray()
    for ty in range(tile_rows):
        for tx in range(tile_cols):
            px0, py0 = tx * TILE_W, ty * TILE_H
            for row in range(TILE_H):
                y = py0 + row
                for col in range(0, TILE_W, 2):
                    x = px0 + col
                    p0 = indices[y * iw + x]
                    p1 = indices[y * iw + x + 1]
                    tile_data.append(encode_mode0_byte(p0, p1))

    n_tiles = tile_cols * tile_rows
    print(f"Tileset: {W}x{H} px → {tile_cols}×{tile_rows} = {n_tiles} tiles, {len(colours)} colours")
    return asic_palette, bytes(tile_data), tile_cols, tile_rows


# ---------------------------------------------------------------------------
# Map loaders
# ---------------------------------------------------------------------------

def _parse_csv_text(text):
    rows = []
    for line in text.strip().splitlines():
        line = line.strip().rstrip(',')
        if not line:
            continue
        rows.append([int(v.strip()) for v in line.split(',')])
    return rows


def load_map_csv(path):
    """Plain CSV — values are 0-based tile IDs."""
    with open(path) as f:
        rows = _parse_csv_text(f.read())
    return rows


def load_map_tiled_tmx(path):
    """
    Tiled .tmx XML with CSV encoding.
    Tiled tile IDs are 1-based (0 = empty); subtract 1 to get 0-based.
    """
    tree = ET.parse(path)
    root = tree.getroot()
    layer = root.find('.//layer/data[@encoding="csv"]')
    if layer is None:
        sys.exit("TMX error: no CSV-encoded layer found. Export layer with CSV encoding.")
    rows = _parse_csv_text(layer.text)
    # Tiled uses 1-based IDs, convert to 0-based
    rows = [[max(0, v - 1) for v in row] for row in rows]
    return rows


def load_map_tiled_csv(path):
    """Tiled CSV export — 1-based tile IDs, convert to 0-based."""
    with open(path) as f:
        rows = _parse_csv_text(f.read())
    rows = [[max(0, v - 1) for v in row] for row in rows]
    return rows


def make_blank_map(w, h):
    return [[0] * w for _ in range(h)]


def encode_map(rows, map_w, map_h):
    data = bytearray()
    for r in range(map_h):
        row = rows[r] if r < len(rows) else [0] * map_w
        for c in range(map_w):
            data.append(row[c] if c < len(row) else 0)
    return bytes(data)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description='Import tileset PNG + map → CPC+ asset binary')
    p.add_argument('tileset',           help='Tileset PNG')
    p.add_argument('--out',             default='asset.bin', help='Output asset binary (default: asset.bin)')
    p.add_argument('--map-csv',         metavar='FILE', help='Map as plain CSV (0-based tile IDs)')
    p.add_argument('--map-tiled',       metavar='FILE', help='Map as Tiled .tmx or Tiled CSV export (1-based IDs)')
    p.add_argument('--map-width',  '-W', type=int, default=20)
    p.add_argument('--map-height', '-H', type=int, default=25)
    p.add_argument('--colors',          type=int, default=16)
    args = p.parse_args()

    img = Image.open(args.tileset).convert('RGB')
    palette_bytes, tile_bytes, tcols, trows = encode_tileset(img, args.colors)

    if args.map_csv:
        rows = load_map_csv(args.map_csv)
        print(f"Map: plain CSV {args.map_csv}")
    elif args.map_tiled:
        if args.map_tiled.endswith('.tmx'):
            rows = load_map_tiled_tmx(args.map_tiled)
            print(f"Map: Tiled TMX {args.map_tiled}")
        else:
            rows = load_map_tiled_csv(args.map_tiled)
            print(f"Map: Tiled CSV {args.map_tiled}")
    else:
        rows = make_blank_map(args.map_width, args.map_height)
        print(f"Map: blank {args.map_width}×{args.map_height}")

    map_bytes = encode_map(rows, args.map_width, args.map_height)

    out = palette_bytes + tile_bytes + map_bytes
    with open(args.out, 'wb') as f:
        f.write(out)

    n_tiles = len(tile_bytes) // BYTES_PER_TILE
    print(f"Output: palette={len(palette_bytes)}B  tiles={n_tiles}×{BYTES_PER_TILE}B={len(tile_bytes)}B  map={len(map_bytes)}B  total={len(out)}B → {args.out}")


if __name__ == '__main__':
    main()
