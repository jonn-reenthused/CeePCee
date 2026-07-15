#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
ihx_to_bin.py - Convert SDCC Intel HEX output to a flat binary.
Usage: ihx_to_bin.py <input.ihx> <output.bin> [base_addr]

base_addr: hex address of the start of the output binary (default: auto-detect lowest address).
The output binary spans from base_addr to the highest used byte, padded with 0xFF.
"""
import sys

def ihx_to_bin(ihx_path, bin_path, base_addr=None):
    memory = {}
    with open(ihx_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line.startswith(':'):
                continue
            data = bytes.fromhex(line[1:])
            byte_count = data[0]
            address    = (data[1] << 8) | data[2]
            rec_type   = data[3]
            if rec_type == 0x00:  # data record
                for i, b in enumerate(data[4:4+byte_count]):
                    memory[address + i] = b
            elif rec_type == 0x01:  # EOF
                break

    if not memory:
        print("ERROR: no data records found in IHX", file=sys.stderr)
        sys.exit(1)

    lo = min(memory)
    hi = max(memory)

    if base_addr is None:
        base_addr = lo
    elif isinstance(base_addr, str):
        base_addr = int(base_addr, 0)

    if base_addr > lo:
        print(f"WARNING: base_addr ${base_addr:04X} > lowest address ${lo:04X}, clamping", file=sys.stderr)
        base_addr = lo

    size = hi - base_addr + 1
    buf = bytearray([0xFF] * size)
    for addr, val in memory.items():
        offset = addr - base_addr
        if 0 <= offset < size:
            buf[offset] = val

    with open(bin_path, 'wb') as f:
        f.write(buf)

    print(f"  ${lo:04X}-${hi:04X}  ({size} bytes)  -> {bin_path}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    base = int(sys.argv[3], 0) if len(sys.argv) > 3 else None
    ihx_to_bin(sys.argv[1], sys.argv[2], base)
