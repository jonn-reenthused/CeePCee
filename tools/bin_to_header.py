#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
bin_to_header.py - Wrap a binary file as a C const uint8_t array header.

Usage:
  python3 bin_to_header.py input.bin array_name > output.h
"""
import sys

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.bin array_name", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    array_name = sys.argv[2]
    guard = array_name.upper() + '_H'

    data = open(input_path, 'rb').read()

    print(f'#ifndef {guard}')
    print(f'#define {guard}')
    print(f'#include "cpc_types.h"')
    print(f'#define {array_name.upper()}_SIZE {len(data)}')
    print(f'static const uint8_t {array_name}[{len(data)}] = {{')

    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_vals = ', '.join(f'0x{b:02X}' for b in chunk)
        print(f'    {hex_vals},')

    print('};')
    print(f'#endif')

if __name__ == '__main__':
    main()
