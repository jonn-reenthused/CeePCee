/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Simple sprite demo
*/

#include "cpc.h"
#include "cpc_init.h"
#include "cpc_sprite.h"
#include "cpc_input.h"

/*
 * sprite_demo - CPC+ / GX4000 hardware sprite test
 *
 * Displays sprite 0 bouncing around the screen.
 * Sprite is a 16x16 two-colour checkerboard pattern.
 * Palette: colour 1 = bright red, colour 2 = bright white.
 */

/* 16x16 sprite pixel data: 1 byte per pixel, bits 3..0 = colour index.
 * index 0 = transparent, 1 = pen 1 (red), 2 = pen 2 (white).
 * Test: solid red sprite to verify pixel upload works */
#define R 0x01
static const uint8_t sprite_gfx[256] = {
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
    R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,R,
};
#undef R
#undef W

/* Sprite palette: 15 entries (pen 0 = transparent, not in table).
 * Format: 0x0GRB (4-bit each channel).
 * pen 1 = bright red  (G=$0, R=$F, B=$0) -> 0x00F0
 * pen 2 = bright white(G=$F, R=$F, B=$F) -> 0x0FFF
 * pens 3..15 = black */
static const uint16_t sprite_pal[15] = {
    0x00F0,  /* pen 1: bright red */
    0x0FFF,  /* pen 2: bright white */
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000,
};

#define SPR_X_MIN  32    /* left visible edge */
#define SPR_X_MAX 662    /* right visible edge minus 16px sprite width */
#define SPR_Y_MIN   0    /* top visible edge */
#define SPR_Y_MAX 180    /* bottom visible edge minus 16px sprite height */

static const uint8_t asic_seq[17] = {
    0xFF,0x00,0xFF,0x77,0xB3,0x51,0xA8,0xD4,
    0x62,0x39,0x9C,0x46,0x2B,0x15,0x8A,0xCD,0xEE
};

/* Fixed addresses just above the SDK state block so inline asm can use literals */
__at(0xB090) static int16_t x_pos;
__at(0xB092) static int16_t y_pos;
__at(0xB094) static int8_t  x_dir;
__at(0xB095) static int8_t  y_dir;

void main(void) {
    x_pos = 100; y_pos = 90; x_dir = 1; y_dir = 1;

    cpc_sprite_set_pixels(0, sprite_gfx);
    cpc_sprite_set_palette(sprite_pal);
    cpc_sprite_show(0, 1);

    while (1) {
        cpc_vblank_wait();

        x_pos += x_dir;
        y_pos += y_dir;

        if (x_pos < SPR_X_MIN) { x_pos = SPR_X_MIN; x_dir = 1; }
        if (x_pos > SPR_X_MAX) { x_pos = SPR_X_MAX; x_dir = -1; }
        if (y_pos < SPR_Y_MIN) { y_pos = SPR_Y_MIN; y_dir = 1; }
        if (y_pos > SPR_Y_MAX) { y_pos = SPR_Y_MAX; y_dir = -1; }

        __asm
            ld      b, #0xBC
            ld      hl, #_asic_seq
            ld      e, #17
        00020$:
            ld      a, (hl)
            out     (c), a
            inc     hl
            dec     e
            jr      nz, 00020$
            di
            ld      bc, #0x7FB8
            out     (c), c
            ld      hl, (0xB090)
            ld      (0x6000), hl
            ld      hl, (0xB092)
            ld      (0x6002), hl
            ld      bc, #0x7FA0
            out     (c), c
            ei
        __endasm;
    }
}
