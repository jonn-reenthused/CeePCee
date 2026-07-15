/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"
#include "furelise.h"
#include "cpc_text.h"

/* Minimal debug - check if silence_all works */

void main(void) {
    unsigned char mixer;
    char buf[16];
    
    cpc_init(CPC_MODE_0);
    cpc_text_init();

    /* Check mixer after init */
    __asm__("ld a, (#0xB180)");
    __asm__("ld %0, a" : "=r"(mixer));
    
    sprintf(buf, "M:%02X", mixer);
    cpc_text_print_at(0, 0, buf);
    
    /* Call silence_all and check again */
    cpc_sound_silence_all();
    
    __asm__("ld a, (#0xB180)");
    __asm__("ld %0, a" : "=r"(mixer));
    sprintf(buf, "S:%02X", mixer);
    cpc_text_print_at(0, 1, buf);
    
    /* Now start music */
    cpc_music_set_tempo(FURELIS3_TEMPO);
    cpc_music_play(FURELIS3_periods, FURELIS3_volumes, FURELIS3_STEPS);

    while (1) {
        cpc_vblank_wait();
        cpc_music_tick();
    }
}
