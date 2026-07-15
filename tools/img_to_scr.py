#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
img_to_scr.py - Convert PNG image to CPC+ screen binary

Output format (.bin):
  Bytes  0-31  : ASIC palette — 16 x uint16_t (little-endian), format 0x0GRB
  Bytes 32-    : Screen pixel data
                 Mode 0: 16000 bytes (160x200, 2px/byte, bit-interleaved)
                 Mode 1: 16000 bytes (320x200, 4px/byte, bit-interleaved)

Usage:
  python3 img_to_scr.py input.png output.bin [--mode 0|1]

Requires: Pillow  (pip install Pillow)
"""

import sys
import argparse
import struct
from PIL import Image

def rgb_to_asic(r, g, b):
    """Convert 8-bit RGB to CPC+ ASIC 12-bit colour: 0x0GRB (4 bits each)."""
    r4 = (r + 8) >> 4
    g4 = (g + 8) >> 4
    b4 = (b + 8) >> 4
    if r4 > 15: r4 = 15
    if g4 > 15: g4 = 15
    if b4 > 15: b4 = 15
    return (g4 << 8) | (r4 << 4) | b4

def encode_mode0_byte(p0, p1):
    """
    Encode two Mode 0 pixel indices (0-15) into one screen byte.
    CPC Mode 0 bit layout (pen index bits b3b2b1b0):
      Bit7 = p0.b0  Bit6 = p1.b0
      Bit5 = p0.b1  Bit4 = p1.b1
      Bit3 = p0.b2  Bit2 = p1.b2
      Bit1 = p0.b3  Bit0 = p1.b3
    """
    b = 0
    for i in range(4):
        b |= ((p0 >> i) & 1) << (7 - i*2)
        b |= ((p1 >> i) & 1) << (6 - i*2)
    return b

def encode_mode1_byte(p0, p1, p2, p3):
    """
    Encode four Mode 1 pixel indices (0-3) into one screen byte.
    CPC Mode 1 bit layout (pen index bits b1b0):
      Bit7 = p0.b0  Bit6 = p1.b0  Bit5 = p2.b0  Bit4 = p3.b0
      Bit3 = p0.b1  Bit2 = p1.b1  Bit1 = p2.b1  Bit0 = p3.b1
    """
    return (((p0 >> 0) & 1) << 7 |
            ((p1 >> 0) & 1) << 6 |
            ((p2 >> 0) & 1) << 5 |
            ((p3 >> 0) & 1) << 4 |
            ((p0 >> 1) & 1) << 3 |
            ((p1 >> 1) & 1) << 2 |
            ((p2 >> 1) & 1) << 1 |
            ((p3 >> 1) & 1) << 0)

def quantise(img, n_colours):
    """Quantise image to n_colours using median-cut via Pillow."""
    img = img.convert('RGB')
    q = img.quantize(colors=n_colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    q = q.convert('P')
    palette_raw = q.getpalette()
    indices = list(q.getdata())
    used = sorted(set(indices))
    remap = {old: new for new, old in enumerate(used)}
    indices = [remap[i] for i in indices]
    colours = []
    for i in used:
        r, g, b = palette_raw[i*3], palette_raw[i*3+1], palette_raw[i*3+2]
        colours.append((r, g, b))
    while len(colours) < n_colours:
        colours.append((0, 0, 0))
    return indices, colours

def convert(input_path, output_path, mode):
    n_colours = 16 if mode == 0 else 4
    target_w  = 160 if mode == 0 else 320
    target_h  = 200

    img = Image.open(input_path).convert('RGB')

    if img.size != (target_w, target_h):
        print(f"Resizing {img.size} -> ({target_w}, {target_h})")
        img = img.resize((target_w, target_h), Image.LANCZOS)

    indices, colours = quantise(img, n_colours)

    asic_palette = [rgb_to_asic(r, g, b) for r, g, b in colours]
    while len(asic_palette) < 16:
        asic_palette.append(0)

    palette_bytes = b''.join(struct.pack('<H', c) for c in asic_palette)

    # CPC VRAM layout: $C000-$FFFF = 16384 bytes total.
    # Screen is 25 char rows x 8 scan lines. Each scan line is 80 bytes wide.
    # For scan line y, byte offset within the 16384-byte VRAM buffer is:
    #   (y // 8) * 80 + (y % 8) * 2048 + x_byte
    # where x_byte = x // 2 (mode 0) or x // 4 (mode 1).
    # The 2048-byte stride comes from the CRTC R9=7 (8 lines/char) x 256 bytes/line
    # but the physical layout uses 2048 = 0x800 byte increments per scan line within a char row.
    bytes_per_line = target_w // (2 if mode == 0 else 4)  # 80
    total_bytes = 0x4000 - 32                              # 16352 = 16KB bank minus 32-byte palette header
    pixels = bytearray(total_bytes)

    if mode == 0:
        for y in range(target_h):
            offset = (y // 8) * bytes_per_line + (y % 8) * 2048
            for x in range(0, target_w, 2):
                p0 = indices[y * target_w + x]
                p1 = indices[y * target_w + x + 1]
                pixels[offset + x // 2] = encode_mode0_byte(p0, p1)
    else:
        for y in range(target_h):
            offset = (y // 8) * bytes_per_line + (y % 8) * 2048
            for x in range(0, target_w, 4):
                p0 = indices[y * target_w + x]
                p1 = indices[y * target_w + x + 1]
                p2 = indices[y * target_w + x + 2]
                p3 = indices[y * target_w + x + 3]
                pixels[offset + x // 4] = encode_mode1_byte(p0, p1, p2, p3)

    assert len(pixels) == total_bytes, f"Pixel data length {len(pixels)} != {total_bytes}"

    with open(output_path, 'wb') as f:
        f.write(palette_bytes)
        f.write(pixels)

    print(f"Mode {mode}: {target_w}x{target_h}, {n_colours} colours -> {output_path}")
    print(f"  Palette ({len(palette_bytes)} bytes) + VRAM ({len(pixels)} bytes) = {len(palette_bytes)+len(pixels)} bytes total")
    print(f"  Colours used:")
    for i, (asic, (r, g, b)) in enumerate(zip(asic_palette[:n_colours], colours[:n_colours])):
        print(f"    pen {i:2d}: RGB({r:3d},{g:3d},{b:3d}) -> ASIC 0x{asic:04X}")

def main():
    parser = argparse.ArgumentParser(description='Convert PNG to CPC+ screen binary')
    parser.add_argument('input',  help='Input PNG file')
    parser.add_argument('output', help='Output .bin file')
    parser.add_argument('--mode', type=int, choices=[0, 1], default=0,
                        help='Screen mode: 0=160x200x16, 1=320x200x4 (default: 0)')
    args = parser.parse_args()
    convert(args.input, args.output, args.mode)

if __name__ == '__main__':
    main()
