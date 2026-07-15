/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_SPRITE_H
#define CPC_SPRITE_H

#include "cpc_types.h"

/*
 * CPC+ / GX4000 Hardware Sprites
 *
 * 16 hardware sprites, each 16x16 pixels, Mode 0 encoding (4bpp).
 * Pixel data = 256 bytes per sprite (16 rows x 16 bytes).
 * Each nibble selects a colour from the 15-entry sprite palette.
 * Colour 0 is transparent.
 *
 * Coordinates are in monitor pixels. Sprite (0,0) is off the left/top edge;
 * (32,64) places the sprite at the top-left of the visible display area
 * (depends on CRTC settings).
 *
 * Magnification byte format (ASIC register at $6004 + id*8):
 *   bits 1..0 = Y magnification: 00 = hidden, 01 = x1, 10 = x2, 11 = x4
 *   bits 3..2 = X magnification: 00 = hidden, 01 = x1, 10 = x2, 11 = x4
 *   bits 7..4 are ignored.
 */

#define SPRITE_MAG_X1   1   /* 01 = x1 */
#define SPRITE_MAG_X2   2   /* 10 = x2 */
#define SPRITE_MAG_X4   3   /* 11 = x4 */
#define SPRITE_MAG_OFF  0   /* 00 = sprite not visible */

/* Presets for common screen modes. These make the sprite pixels match the
 * width of the screen pixels in that mode, so a 16x16 sprite looks square. */
#define SPRITE_MAG_MODE_0  0x0D   /* x4 X, x1 Y */
#define SPRITE_MAG_MODE_1  0x09   /* x2 X, x1 Y */
#define SPRITE_MAG_MODE_2  0x05   /* x1 X, x1 Y */

/* Legacy names (kept for compatibility). */
#define SPRITE_MAG_NORMAL   SPRITE_MAG_MODE_2  /* 1x X, 1x Y */
#define SPRITE_MAG_2X_WIDE  0x06               /* 2x X, 1x Y */
#define SPRITE_MAG_2X_TALL  0x09               /* 1x X, 2x Y */
#define SPRITE_MAG_2X_BOTH  0x0A               /* 2x X, 2x Y */

/* Build a magnification byte from X and Y zoom values.
 * x_mag / y_mag: SPRITE_MAG_X1, SPRITE_MAG_X2, SPRITE_MAG_X4 or SPRITE_MAG_OFF.
 */
#define cpc_sprite_mag(x_mag, y_mag) \
    ((((x_mag) & 0x03) << 2) | ((y_mag) & 0x03))

/*
 * cpc_sprite_set_pixels(id, pixels)
 * Upload 256 bytes of pixel data for sprite <id> (0..15).
 * pixels: pointer to 256 bytes in Mode 0 nibble format.
 */
void cpc_sprite_set_pixels(uint8_t id, const uint8_t *pixels);

/*
 * cpc_sprite_set_palette(colours)
 * Set all 15 sprite palette entries from a 15-entry array of
 * CPC+ ASIC RGB colour values (16-bit, 0x0GRB format).
 */
void cpc_sprite_set_palette(const uint16_t *colours);

/*
 * cpc_sprite_show(id, visible)
 * Show (visible=1) or hide (visible=0) a hardware sprite.
 */
void cpc_sprite_show(uint8_t id, uint8_t visible);

/*
 * cpc_sprite_move(id, x, y)
 * Set sprite position in screen pixel coordinates.
 */
void cpc_sprite_move(uint8_t id, uint16_t x, uint16_t y);

/*
 * cpc_sprite_set_x(id, x) / cpc_sprite_set_y(id, y)
 * Set sprite X or Y position individually. Prefer these over cpc_sprite_move
 * when only one axis changes, or to avoid 3-argument calling convention issues.
 */
void cpc_sprite_set_x(uint8_t id, uint16_t x);
void cpc_sprite_set_y(uint8_t id, uint16_t y);

/*
 * cpc_sprite_set_magnification(id, mag)
 * Set sprite magnification. Use SPRITE_MAG_MODE_* or the cpc_sprite_mag() helper.
 * Example: cpc_sprite_set_magnification(0, SPRITE_MAG_MODE_1);
 *          cpc_sprite_set_magnification(0, cpc_sprite_mag(SPRITE_MAG_X2, SPRITE_MAG_X1));
 */
void cpc_sprite_set_magnification(uint8_t id, uint8_t mag);

/*
 * cpc_sprite_collides(id_a, id_b, tolerance)
 * Returns 1 if sprites <id_a> and <id_b> overlap within <tolerance> pixels.
 * Returns 0 if not overlapping.
 */
uint8_t cpc_sprite_collides(uint8_t id_a, uint8_t id_b, uint8_t tolerance);

#endif
