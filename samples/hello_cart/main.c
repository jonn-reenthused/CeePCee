/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Hello world
*/

#include "cpc.h"

void main(void) {
    __asm
        di

        ; Disable lower ROM, set mode 1: $8D = mode1 + upper ROM off + lower ROM off
        ld      bc, #0x7F8D
        out     (c), c

        ; Patch $0038 in RAM with EI;RET
        ld      hl, #0xC9FB
        ld      (#0x0038), hl

        ; Patch $0066 in RAM with RETN
        ld      hl, #0x45ED
        ld      (#0x0066), hl

        ; pen 0=black, pens 1-15=bright white, border=bright red
        ld      b, #0x7F
        ld      c, #0x00
        out     (c), c
        ld      c, #0x54        ; pen 0 = black
        out     (c), c
        ld      e, #1
00091$:
        ld      a, e
        ld      c, a
        out     (c), c
        ld      c, #0x4B        ; bright white
        out     (c), c
        inc     e
        ld      a, e
        cp      #16
        jr      NZ, 00091$
        ld      c, #0x10
        out     (c), c
        ld      c, #0x4C        ; border = bright red
        out     (c), c

        ; Clear screen to pen 0 (black)
        ld      hl, #0xC000
        ld      de, #0xC001
        xor     a
        ld      (hl), a
        ld      bc, #0x3FFF
        ldir

        ei
    __endasm;

    cpc_text_use_firmware_font();
    cpc_text_set_ink(3);
    cpc_text_set_paper(0);
    cpc_text_print(0, 0, "HELLO GX4000!");
    cpc_text_print(0, 2, "CeePCee V2 SDK");
    cpc_text_print(0, 4, "Mode 1 text works.");

    while(1) {}
}
