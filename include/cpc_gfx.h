/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_GFX_H
#define CPC_GFX_H

#include "cpc_types.h"

/*
 * Firmware ink indices (CPC standard palette, 0..26)
 * These are the values accepted by cpc_palette_set_ink() and cpc_border_set().
 */
#define INK_BLACK        0
#define INK_BLUE         1
#define INK_BRIGHT_BLUE  2
#define INK_RED          3
#define INK_MAGENTA      4
#define INK_MAUVE        5
#define INK_BRIGHT_RED   6
#define INK_PURPLE       7
#define INK_BRIGHT_MAGENTA 8
#define INK_GREEN        9
#define INK_CYAN         10
#define INK_SKY_BLUE     11
#define INK_YELLOW       12
#define INK_WHITE        13
#define INK_PASTEL_BLUE  14
#define INK_ORANGE       15
#define INK_PINK         16
#define INK_PASTEL_MAGENTA 17
#define INK_BRIGHT_GREEN 18
#define INK_SEA_GREEN    19
#define INK_BRIGHT_CYAN  20
#define INK_LIME         21
#define INK_PASTEL_GREEN 22
#define INK_ICE          23
#define INK_BRIGHT_YELLOW 24
#define INK_PASTEL_YELLOW 25
#define INK_BRIGHT_WHITE 26

/*
 * cpc_border_set(ink)
 * Set border colour using a firmware ink index (0..26).
 */
void cpc_border_set(uint8_t ink);

/*
 * cpc_palette_set_ink(pen, ink)
 * Set a single screen pen (0..15) to a firmware ink index (0..26).
 */
void cpc_palette_set_ink(uint8_t pen, uint8_t ink);

/*
 * cpc_palette_set(inks)
 * Set all 16 screen pens from a 16-byte array of firmware ink indices.
 */
void cpc_palette_set(const uint8_t *inks);

/*
 * cpc_palette_set_plus(colours)
 * Set all 16 screen colours using CPC+ ASIC RGB format.
 * Each entry is a 16-bit value: 0x0GRB (4 bits each, 0..15).
 * Requires ASIC to be unlocked (done by cpc_init).
 */
void cpc_palette_set_plus(const uint16_t *colours);

/*
 * cpc_screen_clear(ink)
 * Fill screen RAM ($C000..$FFFF) with a single byte value.
 * Pass 0 to clear to black in any mode.
 */
void cpc_screen_clear(uint8_t fill);

/*
 * cpc_screen_load(data)
 * Display a full-screen image from a binary blob in RAM.
 * The boot stub copies CPR asset bank cb01 to RAM $4000 before main() runs.
 * Call as: cpc_screen_load((const uint8_t*)0x4000)
 *
 * Data format (produced by img_to_scr.py):
 *   Bytes  0-31 : ASIC palette (16 x uint16_t LE, 0x0GRB)
 *   Bytes 32+   : Screen pixel data (16000 bytes, Mode 0 or Mode 1)
 */
void cpc_screen_load(const uint8_t *data);

#endif
