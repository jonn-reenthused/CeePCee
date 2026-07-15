/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Simple Input and sprite movement demo
*/

#include "cpc.h"
#include "cpc_text.h"
#include "cpc_input.h"
#include "cpc_sprite.h"

/*
 * input_demo - CPC+ / GX4000 input test
 *
 * Shows a sprite that moves with joystick/cursor keys.
 * Prints which direction and button is pressed.
 * Press fire 1 to cycle the sprite colour.
 * Tests both cpc_input_* (joystick) and cpc_key_held (keyboard).
 */

#define R 0x01
#define W 0x02
#define B 0x03
static const uint8_t sprite_gfx[256] = {
    0,0,0,0,R,R,R,R,R,R,R,R,0,0,0,0,
    0,0,0,R,R,R,R,R,R,R,R,R,R,0,0,0,
    0,0,R,R,R,W,W,W,W,W,W,R,R,R,0,0,
    0,R,R,R,W,W,W,W,W,W,W,W,R,R,R,0,
    0,R,R,W,W,W,W,W,W,W,W,W,W,R,R,0,
    R,R,R,W,W,W,W,W,W,W,W,W,W,R,R,R,
    R,R,W,W,W,W,W,W,W,W,W,W,W,W,R,R,
    R,R,W,W,W,W,W,W,W,W,W,W,W,W,R,R,
    R,R,W,W,W,W,W,W,W,W,W,W,W,W,R,R,
    R,R,W,W,W,W,W,W,W,W,W,W,W,W,R,R,
    R,R,R,W,W,W,W,W,W,W,W,W,W,R,R,R,
    0,R,R,W,W,W,W,W,W,W,W,W,W,R,R,0,
    0,R,R,R,W,W,W,W,W,W,W,W,R,R,R,0,
    0,0,R,R,R,W,W,W,W,W,W,R,R,R,0,0,
    0,0,0,R,R,R,R,R,R,R,R,R,R,0,0,0,
    0,0,0,0,R,R,R,R,R,R,R,R,0,0,0,0,
};
#undef R
#undef W
#undef B

/* Sprite palette: pen 1 = red, pen 2 = white, pen 3 = blue */
static const uint16_t sprite_pal[15] = {
    0x00F0,  /* pen 1: bright red   */
    0x0FFF,  /* pen 2: bright white */
    0x000F,  /* pen 3: bright blue  */
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000,
};

/* Screen palette: black background, white text, bright red border */
static const uint8_t screen_pal[16] = {
    INK_BLACK, INK_WHITE, INK_WHITE, INK_WHITE,
    INK_WHITE, INK_WHITE, INK_WHITE, INK_WHITE,
    INK_WHITE, INK_WHITE, INK_WHITE, INK_WHITE,
    INK_WHITE, INK_WHITE, INK_WHITE, INK_WHITE
};

#define SPR_X_MIN  32
#define SPR_X_MAX 646    /* 662 - 16px for sprite width */
#define SPR_Y_MIN   0
#define SPR_Y_MAX 164    /* 180 - 16px for sprite height */

#define MOVE_SPEED  2

static int16_t spr_x;
static int16_t spr_y;

static void update_sprite_pos(void)
{
    cpc_sprite_set_x(0, spr_x);
    cpc_sprite_set_y(0, spr_y);
}

static void draw_label(uint8_t col, uint8_t row, uint8_t active)
{
    cpc_text_clear(col, row, 3);
    cpc_text_print(col, row, active ? "YES" : "NO ");
}

void main(void)
{
    uint8_t col = 1;

    /* Hardware setup: mode 1, palette, clear screen */
    cpc_init(CPC_MODE_1);
    cpc_screen_clear(0);
    cpc_palette_set(screen_pal);
    cpc_border_set(INK_BRIGHT_RED);

    spr_x = 320; spr_y = 90;

    cpc_text_use_firmware_font();
    cpc_text_set_ink(3);
    cpc_text_set_paper(0);

    cpc_sprite_set_pixels(0, sprite_gfx);
    cpc_sprite_set_palette(sprite_pal);
    cpc_sprite_show(0, 1);
    update_sprite_pos();

    cpc_text_print(0, 0,  "INPUT DEMO");
    cpc_text_print(0, 2,  "JOYSTICK     KEYBOARD");
    cpc_text_print(0, 4,  "UP   :        CUR_U:");
    cpc_text_print(0, 5,  "DOWN :        CUR_D:");
    cpc_text_print(0, 6,  "LEFT :        CUR_L:");
    cpc_text_print(0, 7,  "RIGHT:        CUR_R:");
    cpc_text_print(0, 8,  "FIRE1:        SPACE:");
    cpc_text_print(0, 9,  "FIRE2:        RETN :");

    while (1) {
        cpc_vblank_wait();

        /* --- Movement: joystick OR cursor keys --- */
        if (cpc_input_up(PLAYER_1)   || cpc_key_held(KEY_CUR_U)) {
            spr_y -= MOVE_SPEED;
            if (spr_y < SPR_Y_MIN) spr_y = SPR_Y_MIN;
        }
        if (cpc_input_down(PLAYER_1) || cpc_key_held(KEY_CUR_D)) {
            spr_y += MOVE_SPEED;
            if (spr_y > SPR_Y_MAX) spr_y = SPR_Y_MAX;
        }
        if (cpc_input_left(PLAYER_1) || cpc_key_held(KEY_CUR_L)) {
            spr_x -= MOVE_SPEED;
            if (spr_x < SPR_X_MIN) spr_x = SPR_X_MIN;
        }
        if (cpc_input_right(PLAYER_1) || cpc_key_held(KEY_CUR_R)) {
            spr_x += MOVE_SPEED;
            if (spr_x > SPR_X_MAX) spr_x = SPR_X_MAX;
        }

        update_sprite_pos();

        /* --- Fire 1 / Space: cycle sprite outline colour --- */
        if (cpc_input_button1_pressed(PLAYER_1) || cpc_key_pressed(KEY_SPACE)) {
            col++;
            if (col > 3) col = 1;
        }

        /* --- Joystick column --- */
        draw_label(7, 4, cpc_input_up(PLAYER_1));
        draw_label(7, 5, cpc_input_down(PLAYER_1));
        draw_label(7, 6, cpc_input_left(PLAYER_1));
        draw_label(7, 7, cpc_input_right(PLAYER_1));
        draw_label(7, 8, cpc_input_button1(PLAYER_1));
        draw_label(7, 9, cpc_input_button2(PLAYER_1));

        /* --- Keyboard column --- */
        draw_label(21, 4, cpc_key_held(KEY_CUR_U));
        draw_label(21, 5, cpc_key_held(KEY_CUR_D));
        draw_label(21, 6, cpc_key_held(KEY_CUR_L));
        draw_label(21, 7, cpc_key_held(KEY_CUR_R));
        draw_label(21, 8, cpc_key_held(KEY_SPACE));
        draw_label(21, 9, cpc_key_held(KEY_RETN));
    }
}
