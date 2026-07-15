/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Sample redefine keys screen
*/

#include "cpc_init.h"
#include "cpc_text.h"
#include "cpc_input.h"
#include "cpc_sprite.h"

/*
 * redefine_demo - demonstrates key rebinding using cpc_key_name() and
 * cpc_key_pressed() for capture, cpc_key_held() for gameplay.
 *
 * Controls:
 *   Press FIRE1 (joystick) or highlight an action with UP/DOWN and
 *   press RETN to enter "waiting" mode, then press any key to bind it.
 */

/* ---- Sprite data -------------------------------------------------------- */
static const uint8_t sprite_gfx[256] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,
    0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0,
    0,0,0,1,2,2,1,1,2,2,2,1,0,0,0,0,
    0,0,1,2,2,1,0,0,1,2,2,2,1,0,0,0,
    0,0,1,2,1,0,0,0,0,1,2,2,1,0,0,0,
    0,0,1,2,1,0,0,0,0,1,2,2,1,0,0,0,
    0,0,1,2,2,1,0,0,1,2,2,2,1,0,0,0,
    0,0,0,1,2,2,1,1,2,2,2,1,0,0,0,0,
    0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0,
    0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
};

static const uint16_t sprite_pal[15] = {
    0x0000, 0x0F00, 0x0FF0, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000
};

/* ---- Sprite position (fixed addresses above SDK state block) ------------ */
#define SPR_X_MIN  32
#define SPR_X_MAX 646
#define SPR_Y_MIN   0
#define SPR_Y_MAX 164
#define MOVE_SPEED  2

/* ASIC unlock sequence */
static const uint8_t asic_seq[17] = {
    0xFF,0x00,0xFF,0x77,0xB3,0x51,0xA8,0xD4,
    0x62,0x39,0x9C,0x46,0x2B,0x15,0x8A,0xCD,0xEE
};

__at(0xB700) static int16_t spr_x;
__at(0xB702) static int16_t spr_y;

static void update_sprite_pos(void)
{
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
        ld      hl, (0xB700)
        ld      (0x6000), hl
        ld      hl, (0xB702)
        ld      (0x6002), hl
        ld      bc, #0x7FA0
        out     (c), c
        ei
    __endasm;
}

/* ---- Key bindings ------------------------------------------------------- */
#define NUM_ACTIONS 5
#define ACTION_UP    0
#define ACTION_DOWN  1
#define ACTION_LEFT  2
#define ACTION_RIGHT 3
#define ACTION_FIRE  4

static const char * const action_names[NUM_ACTIONS] = {
    "UP   ", "DOWN ", "LEFT ", "RIGHT", "FIRE "
};

/* Default bindings: cursor keys + space */
static uint8_t bindings[NUM_ACTIONS] = {
    KEY_CUR_U, KEY_CUR_D, KEY_CUR_L, KEY_CUR_R, KEY_SPACE
};

/* ---- UI layout ---------------------------------------------------------- */
#define COL_ACTION  0
#define COL_KEY     8
#define ROW_FIRST   2
#define ROW_STATUS  (ROW_FIRST + NUM_ACTIONS + 1)

static uint8_t selected;    /* currently highlighted action row */
static uint8_t waiting;     /* 1 = waiting for a key press to bind */
static uint8_t releasing;   /* 1 = waiting for keys released, 2 = settle frame */
static uint8_t nav_delay;   /* repeat-rate limiter for navigation */

/*
 * Fixed-width row buffer: "AAAAA : KKKKK      X"
 *  col 0-4  : action name (5 chars)
 *  col 5    : space
 *  col 6    : ':'
 *  col 7    : space
 *  col 8-12 : key name (up to 5 chars, space-padded)
 *  col 13-19: spaces
 *  col 20   : cursor '<' or ' '
 *  col 21   : null
 */
static char row_buf[22];

static char kname_buf[6];       /* copy of key name, stable across calls */

static void copy_kname(uint8_t key)
{
    /* cpc_key_name returns pointer in HL (sdcccall(1)).
       SDCC incorrectly stores DE; capture HL via inline asm instead.
       Copy up to 5 chars, stop at null and space-pad the rest. */
    __asm
        call    _cpc_key_name
        ld      b, #5
        ld      de, #_kname_buf
00201$:
        ld      a, (hl)
        or      a
        jr      z, 00202$
        ld      (de), a
        inc     hl
        inc     de
        djnz    00201$
        jr      00203$
00202$:
        ld      a, #0x20
        ld      (de), a
        inc     de
        djnz    00202$
00203$:
        xor     a
        ld      (de), a
    __endasm;
    (void)key;
}

static void build_row(uint8_t i)
{
    uint8_t j;

    /* copy key name into stable buffer before touching anything else */
    copy_kname(bindings[i]);
    /* action name - always 5 chars */
    row_buf[0] = action_names[i][0];
    row_buf[1] = action_names[i][1];
    row_buf[2] = action_names[i][2];
    row_buf[3] = action_names[i][3];
    row_buf[4] = action_names[i][4];
    row_buf[5] = ' ';
    row_buf[6] = ':';
    row_buf[7] = ' ';

    /* key name padded to 5 chars */
    for (j = 0; j < 5; j++) {
        row_buf[8 + j] = kname_buf[j] ? kname_buf[j] : ' ';
    }

    /* trailing spaces + cursor + null */
    row_buf[13] = ' '; row_buf[14] = ' '; row_buf[15] = ' ';
    row_buf[16] = ' '; row_buf[17] = ' '; row_buf[18] = ' ';
    row_buf[19] = ' ';
    row_buf[20] = (i == selected) ? '<' : ' ';
    row_buf[21] = 0;
}

static uint8_t draw_row_num;

static void draw_status(void)
{
    if (waiting) {
        cpc_text_print(0, ROW_STATUS, ">>> PRESS A KEY <<<     ");
    } else {
        cpc_text_print(0, ROW_STATUS, "                        ");
    }
}

static void draw_row(uint8_t i)
{
    if (i >= NUM_ACTIONS) return;
    draw_row_num = ROW_FIRST + i;
    build_row(i);
    cpc_text_print(COL_ACTION, draw_row_num, row_buf);
}

static void draw_all_rows(void)
{
    uint8_t i;
    for (i = 0; i < NUM_ACTIONS; i++)
        draw_row(i);
}

/* ---- Main -------------------------------------------------------------- */
void main(void)
{
    __asm
        di
        ; GA $89 = mode 1, upper ROM off, LOWER ROM ON (bit2=0).
        ; The boot stub's IM1 handler at $0038 (lower ROM) drives the
        ; frame counter used by cpc_vblank_wait() - never disable it.
        ld      bc, #0x7F89
        out     (c), c
        ld      b, #0x7F
        ld      c, #0x00
        out     (c), c
        ld      c, #0x54
        out     (c), c
        ld      e, #1
    00010$:
        ld      a, e
        ld      c, a
        out     (c), c
        ld      c, #0x4B
        out     (c), c
        inc     e
        ld      a, e
        cp      #16
        jr      NZ, 00010$
        ld      c, #0x10
        out     (c), c
        ld      c, #0x4C
        out     (c), c
        ld      hl, #0xC000
        ld      de, #0xC001
        xor     a
        ld      (hl), a
        ld      bc, #0x3FFF
        ldir
        ei
    __endasm;

    /* CRT0 does not zero BSS - force-initialise all state via volatile writes */
    *((volatile uint8_t*)&selected)  = 0;
    *((volatile uint8_t*)&waiting)   = 0;
    *((volatile uint8_t*)&releasing) = 0;
    *((volatile uint8_t*)&nav_delay) = 0;
    *((volatile uint8_t*)&draw_row_num) = 0;
    bindings[ACTION_UP]    = KEY_CUR_U;
    bindings[ACTION_DOWN]  = KEY_CUR_D;
    bindings[ACTION_LEFT]  = KEY_CUR_L;
    bindings[ACTION_RIGHT] = KEY_CUR_R;
    bindings[ACTION_FIRE]  = KEY_SPACE;

    cpc_text_use_firmware_font();
    cpc_text_set_ink(3);
    cpc_text_set_paper(0);

    cpc_sprite_set_pixels(0, sprite_gfx);
    cpc_sprite_set_palette(sprite_pal);
    spr_x = 200;
    spr_y = 80;
    cpc_sprite_show(0, 1);
    update_sprite_pos();

    cpc_text_print(0, 0, "REDEFINE KEYS DEMO");
    cpc_text_print(0, 1, "J/CUR:select  FIRE/RETN:bind");
    draw_all_rows();
    draw_status();
    cpc_text_print(0, ROW_STATUS + 1, "Move sprite with bound keys");

    {
        while (1) {
        cpc_vblank_wait();

        if (waiting) {
            if (releasing == 2) {
                /* settle frame: prev/curr both zero now, safe to capture */
                releasing = 0;
            } else if (releasing == 1) {
                /* wait until all matrix lines and joystick are clear */
                uint8_t line, any = 0;
                for (line = 0; line < 9; line++) {
                    if (((volatile uint8_t*)0xB158)[line]) { any = 1; break; }
                }
                if (!any && *((volatile uint8_t*)0xB002)) any = 1;
                if (!any) releasing = 2;  /* one more frame to let prev settle */
            } else {
                /* Keyboard: scan lines 0-8 only (0x00-0x47), skip joystick line */
                uint8_t k, found = 0;
                for (k = 0; k < 0x48; k++) {
                    if (cpc_key_pressed(k)) {
                        found = 1;
                        if (k == KEY_ESC) {
                            waiting = 0;
                        } else if (k != KEY_CAPSLK) {
                            bindings[selected] = k;
                            waiting = 0;
                        }
                        draw_row(selected);
                        draw_status();
                        break;
                    }
                }
                /* Joystick: use dedicated pressed functions (edge-detected cleanly) */
                if (!found) {
                    uint8_t jk = 0;
                    if      (cpc_input_up_pressed(PLAYER_1))       jk = KEY_JOY1_U;
                    else if (cpc_input_down_pressed(PLAYER_1))     jk = KEY_JOY1_D;
                    else if (cpc_input_left_pressed(PLAYER_1))     jk = KEY_JOY1_L;
                    else if (cpc_input_right_pressed(PLAYER_1))    jk = KEY_JOY1_R;
                    else if (cpc_input_button1_pressed(PLAYER_1))  jk = KEY_JOY1_F1;
                    else if (cpc_input_button2_pressed(PLAYER_1))  jk = KEY_JOY1_F2;
                    if (jk) {
                        bindings[selected] = jk;
                        waiting = 0;
                        draw_row(selected);
                        draw_status();
                        found = 1;
                    }
                }
            }
        } else {
            /* Navigate selection - cursor keys (RVM/MAME) or joystick (WinAPE) */
            {
                uint8_t up   = cpc_key_pressed(KEY_CUR_U) || cpc_input_up(PLAYER_1);
                uint8_t down = cpc_key_pressed(KEY_CUR_D) || cpc_input_down(PLAYER_1);
                if (!up && !down) {
                    nav_delay = 0;
                } else if (nav_delay == 0) {
                    uint8_t prev = selected;
                    if (up) {
                        if (selected == 0) selected = NUM_ACTIONS - 1;
                        else selected--;
                    } else {
                        if (selected >= NUM_ACTIONS - 1) selected = 0;
                        else selected++;
                    }
                    draw_row(prev);
                    draw_row(selected);
                    nav_delay = 10;
                } else {
                    nav_delay--;
                }
            }
            /* Enter rebind mode - Return key or joystick fire */
            if (cpc_key_pressed(KEY_RETN) || cpc_input_button1(PLAYER_1)) {
                waiting = 1;
                releasing = 1;
                draw_row(selected);
                draw_status();
            }

            /* Move sprite using current bindings */
            if (cpc_key_held(bindings[ACTION_UP])) {
                spr_y -= MOVE_SPEED;
                if (spr_y < SPR_Y_MIN) spr_y = SPR_Y_MIN;
            }
            if (cpc_key_held(bindings[ACTION_DOWN])) {
                spr_y += MOVE_SPEED;
                if (spr_y > SPR_Y_MAX) spr_y = SPR_Y_MAX;
            }
            if (cpc_key_held(bindings[ACTION_LEFT])) {
                spr_x -= MOVE_SPEED;
                if (spr_x < SPR_X_MIN) spr_x = SPR_X_MIN;
            }
            if (cpc_key_held(bindings[ACTION_RIGHT])) {
                spr_x += MOVE_SPEED;
                if (spr_x > SPR_X_MAX) spr_x = SPR_X_MAX;
            }

        }
        update_sprite_pos();
        } /* while */
    } /* fc block */
}
