#!/bin/bash
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard
#
# rom_packer.sh
# Converts a raw binary (.bin) to a CPC Plus/GX4000 .cpr cartridge image.
#
# CPR format:
#   RIFF <size> AMS!
#   repeated chunks: "cbNN" <0x4000> <16KB bank data>
#
# Usage: rom_packer.sh <input.bin> <output.cpr>
# Optional env:
#   CPR_MIN_BANKS=<n>  Minimum number of 16KB banks to emit (default: 8)

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input.bin> <output.cpr>"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

BANK_SIZE=16384
MIN_BANKS=${CPR_MIN_BANKS:-8}

write_u32_le() {
    local v="$1"
    local b0=$(( v        & 255 ))
    local b1=$(( (v >> 8) & 255 ))
    local b2=$(( (v >> 16) & 255 ))
    local b3=$(( (v >> 24) & 255 ))
    printf '%b' "$(printf '\\x%02x\\x%02x\\x%02x\\x%02x' "$b0" "$b1" "$b2" "$b3")"
}

input_size=$(stat -f%z "$INPUT" 2>/dev/null || stat -c%s "$INPUT")

if [ "$input_size" -le 0 ]; then
    echo "Error: Input binary is empty: $INPUT"
    exit 1
fi

# Number of 16KB banks needed to hold the input.
bank_count=$(( (input_size + BANK_SIZE - 1) / BANK_SIZE ))

# Many CPC+/GX4000 emulators expect full cartridge geometry.
# Emit at least MIN_BANKS banks (default 8 = 128KB).
if [ "$bank_count" -lt "$MIN_BANKS" ]; then
    bank_count="$MIN_BANKS"
fi

# RIFF payload size = 4 ("AMS!") + N * (8-byte chunk header + 16KB bank)
riff_payload_size=$(( 4 + bank_count * (8 + BANK_SIZE) ))

rm -f "$OUTPUT"

# RIFF header
printf 'RIFF' >> "$OUTPUT"
write_u32_le "$riff_payload_size" >> "$OUTPUT"
printf 'AMS!' >> "$OUTPUT"

for ((bank=0; bank<bank_count; bank++)); do
    # Chunk tag: cb00, cb01, ... (hex index)
    printf 'cb%02X' "$bank" >> "$OUTPUT"
    write_u32_le "$BANK_SIZE" >> "$OUTPUT"

    bank_offset=$(( bank * BANK_SIZE ))
    remaining=$(( input_size - bank_offset ))
    if [ "$remaining" -le 0 ]; then
        chunk_bytes=0
    elif [ "$remaining" -gt "$BANK_SIZE" ]; then
        chunk_bytes="$BANK_SIZE"
    else
        chunk_bytes="$remaining"
    fi

    # Write bank payload. On BSD/macOS, dd count=0 can still emit data,
    # so guard it explicitly.
    if [ "$chunk_bytes" -gt 0 ]; then
        dd if="$INPUT" bs=1 skip="$bank_offset" count="$chunk_bytes" status=none >> "$OUTPUT"
    fi

    # Pad final bank to full 16KB with 0xFF
    if [ "$chunk_bytes" -lt "$BANK_SIZE" ]; then
        pad=$(( BANK_SIZE - chunk_bytes ))
        LC_ALL=C dd if=/dev/zero bs=1 count="$pad" status=none | LC_ALL=C tr '\000' '\377' >> "$OUTPUT"
    fi
done

echo "Packed cartridge image: $OUTPUT ($(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT") bytes)"
