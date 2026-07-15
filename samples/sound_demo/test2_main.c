/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"
#include "cpc_text.h"
#include "furelise.h"

/* Simple test - does silence_all fix the noise? */

void main(void) {
    unsigned char *mixer = (unsigned char *)0xB180;
    int frame = 0;
    
    cpc_init(CPC_MODE_0);
    cpc_text_init();
    cpc_text_cls();
    cpc_text_print_at(0, 0, "Mixer init:");
    
    /* Show initial mixer value as hex digits */
    unsigned char m = *mixer;
    char hex[3];
    hex[0] = "0123456789ABCDEF"[m >> 4];
    hex[1] = "0123456789ABCDEF"[m & 0xF];
    hex[2] = 0;
    cpc_text_print_at(12, 0, hex);
    
    cpc_text_print_at(0, 2, "Silencing...");
    cpc_sound_silence_all();
    
    cpc_text_print_at(0, 3, "After:");
    m = *mixer;
    hex[0] = "0123456789ABCDEF"[m >> 4];
    hex[1] = "0123456789ABCDEF"[m & 0xF];
    cpc_text_print_at(12, 3, hex);
    
    cpc_text_print_at(0, 5, "Press fire to play");
    
    /* Wait for fire */
    while ((cpc_joy_read(0) & CPC_JOY_FIRE) == 0) {
        cpc_vblank_wait();
    }
    
    cpc_text_print_at(0, 5, "Playing...       ");
    
    cpc_music_set_tempo(FURELIS3_TEMPO);
    cpc_music_play(FURELIS3_periods, FURELIS3_volumes, FURELIS3_STEPS);

    while (1) {
        cpc_vblank_wait();
        cpc_music_tick();
        
        frame++;
        if ((frame & 0x3F) == 0) {
            m = *mixer;
            hex[0] = "0123456789ABCDEF"[m >> 4];
            hex[1] = "0123456789ABCDEF"[m & 0xF];
            cpc_text_print_at(0, 7, "M:");
            cpc_text_print_at(2, 7, hex);
        }
    }
}
