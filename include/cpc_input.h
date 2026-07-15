/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_INPUT_H
#define CPC_INPUT_H

#include "cpc_types.h"

/*
 * Player indices
 */
#define PLAYER_1   0
#define PLAYER_2   1

/*
 * Key codes: encoded as (line_index << 3) | bit
 * line_index = matrix line - $40  (0..9)
 * bit = bit position in that line  (0..7)
 *
 * Matrix layout (active-high after inversion):
 *  Line  Bit7    Bit6    Bit5    Bit4    Bit3    Bit2    Bit1    Bit0
 *  $40   FDot    ENTER   F3      F6      F9      CUR_D   CUR_R   CUR_U
 *  $41   F0      F2      F1      F5      F8      F7      COPY    CUR_L
 *  $42   CTRL    \       SHIFT   F4      ]       RETN    [       CLR
 *  $43   .       /       :       ;       P       @       -       ^
 *  $44   ,       M       K       L       I       O       9       0
 *  $45   SPACE   N       J       H       Y       U       7       8
 *  $46   V       B       F       G/J2F1  T/J2R   R/J2L   5/J2D   6/J2U
 *  $47   X       C       D       S       W       E       3       4
 *  $48   Z       CAPSLK  A       TAB     Q       ESC     2       1
 *  $49   DEL     J1_F3   J1_F2   J1_F1   J1_R    J1_L    J1_D    J1_U
 */

/* Line 0 ($40) */
#define KEY_CUR_U   0x00    /* bit 0 */
#define KEY_CUR_R   0x01    /* bit 1 */
#define KEY_CUR_D   0x02    /* bit 2 */
#define KEY_F9      0x03
#define KEY_F6      0x04
#define KEY_F3      0x05
#define KEY_ENTER   0x06
#define KEY_FDOT    0x07

/* Line 1 ($41) */
#define KEY_CUR_L   0x08    /* bit 0 */
#define KEY_COPY    0x09
#define KEY_F7      0x0A
#define KEY_F8      0x0B
#define KEY_F5      0x0C
#define KEY_F1      0x0D
#define KEY_F2      0x0E
#define KEY_F0      0x0F

/* Line 2 ($42) */
#define KEY_CLR     0x10
#define KEY_LBRACE  0x11
#define KEY_RETN    0x12
#define KEY_RBRACE  0x13
#define KEY_F4      0x14
#define KEY_SHIFT   0x15
#define KEY_BSLASH  0x16
#define KEY_CTRL    0x17

/* Line 3 ($43) */
#define KEY_CARET   0x18
#define KEY_MINUS   0x19
#define KEY_AT      0x1A
#define KEY_P       0x1B
#define KEY_SEMI    0x1C
#define KEY_COLON   0x1D
#define KEY_FSLASH  0x1E
#define KEY_DOT     0x1F

/* Line 4 ($44) */
#define KEY_0       0x20
#define KEY_9       0x21
#define KEY_O       0x22
#define KEY_I       0x23
#define KEY_L       0x24
#define KEY_K       0x25
#define KEY_M       0x26
#define KEY_COMMA   0x27

/* Line 5 ($45) */
#define KEY_8       0x28
#define KEY_7       0x29
#define KEY_U       0x2A
#define KEY_Y       0x2B
#define KEY_H       0x2C
#define KEY_J       0x2D
#define KEY_N       0x2E
#define KEY_SPACE   0x2F

/* Line 6 ($46) */
#define KEY_6       0x30
#define KEY_5       0x31
#define KEY_R       0x32
#define KEY_T       0x33
#define KEY_G       0x34
#define KEY_F       0x35
#define KEY_B       0x36
#define KEY_V       0x37

/* Line 7 ($47) */
#define KEY_4       0x38
#define KEY_3       0x39
#define KEY_E       0x3A
#define KEY_W       0x3B
#define KEY_S       0x3C
#define KEY_D       0x3D
#define KEY_C       0x3E
#define KEY_X       0x3F

/* Line 8 ($48) */
#define KEY_1       0x40
#define KEY_2       0x41
#define KEY_ESC     0x42
#define KEY_Q       0x43
#define KEY_TAB     0x44
#define KEY_A       0x45
#define KEY_CAPSLK  0x46
#define KEY_Z       0x47

/* Line 9 ($49) - joystick 1 shares this line */
#define KEY_JOY1_U  0x48    /* bit 0 */
#define KEY_JOY1_D  0x49    /* bit 1 */
#define KEY_JOY1_L  0x4A    /* bit 2 */
#define KEY_JOY1_R  0x4B    /* bit 3 */
#define KEY_JOY1_F1 0x4C    /* bit 4 */
#define KEY_JOY1_F2 0x4D    /* bit 5 */
#define KEY_JOY1_F3 0x4E    /* bit 6 */
#define KEY_DEL     0x4F    /* bit 7 */

/*
 * cpc_input_poll()
 * Scan the full 10-line keyboard matrix. Called automatically by
 * cpc_vblank_wait() - only call manually if not using vblank wait.
 */
void cpc_input_poll(void);

/*
 * cpc_key_held(key)
 * Returns 1 while the key is held down, 0 otherwise.
 * Use KEY_* constants above.
 */
uint8_t cpc_key_held(uint8_t key);

/*
 * cpc_key_name(key)
 * Returns a pointer to a short null-terminated string naming the key.
 * e.g. cpc_key_name(KEY_SPACE) -> "SPC", cpc_key_name(KEY_A) -> "A"
 * Returns "?" for out-of-range key codes.
 */
const char *cpc_key_name(uint8_t key);

/*
 * cpc_key_pressed(key)
 * Returns 1 on the first frame the key goes down, 0 otherwise.
 * Use KEY_* constants above.
 */
uint8_t cpc_key_pressed(uint8_t key);

/*
 * Joystick / direction helpers (player 1 joystick, or cursor keys on CPC)
 * These read from the raw joystick line (line 9) of the matrix.
 */
uint8_t cpc_input_up(uint8_t player);
uint8_t cpc_input_down(uint8_t player);
uint8_t cpc_input_left(uint8_t player);
uint8_t cpc_input_right(uint8_t player);
uint8_t cpc_input_button1(uint8_t player);
uint8_t cpc_input_button2(uint8_t player);

uint8_t cpc_input_up_pressed(uint8_t player);
uint8_t cpc_input_down_pressed(uint8_t player);
uint8_t cpc_input_left_pressed(uint8_t player);
uint8_t cpc_input_right_pressed(uint8_t player);
uint8_t cpc_input_button1_pressed(uint8_t player);
uint8_t cpc_input_button2_pressed(uint8_t player);

#endif
