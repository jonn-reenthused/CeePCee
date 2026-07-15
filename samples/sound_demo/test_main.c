/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"
#include "cpc_text.h"
#include "furelise.h"

/* Test to verify mixer initialization */

void main(void) {
    unsigned char *mixer_shadow = (unsigned char *)0xB180;
    unsigned char mixer_val;
    char buf[32];
    int frame = 0;
    
    cpc_init(CPC_MODE_0);
    cpc_text_init();
    cpc_text_cls();

    /* Read mixer shadow immediately after init */
    mixer_val = *mixer_shadow;
    sprintf(buf, "Init mixer: %02X", mixer_val);
    cpc_text_print_at(0, 0, buf);
    
    /* Call silence_all and check again */
    cpc_sound_silence_all();
    mixer_val = *mixer_shadow;
    sprintf(buf, "After silence: %02X", mixer_val);
    cpc_text_print_at(0, 1, buf);
    
    /* Check step 0 data */
    sprintf(buf, "P:%d,%d,%d V:%d,%d,%d", 
            FURELIS3_periods[0], FURELIS3_periods[1], FURELIS3_periods[2],
            FURELIS3_volumes[0], FURELIS3_volumes[1], FURELIS3_volumes[2]);
    cpc_text_print_at(0, 3, buf);

    cpc_music_set_tempo(FURELIS3_TEMPO);
    cpc_music_play(FURELIS3_periods, FURELIS3_volumes, FURELIS3_STEPS);
    
    cpc_text_print_at(0, 5, "Playing...");

    while (1) {
        cpc_vblank_wait();
        cpc_music_tick();
        
        frame++;
        if ((frame & 0x3F) == 0) {  /* Update every 64 frames (~1.3 sec) */
            mixer_val = *mixer_shadow;
            sprintf(buf, "Mixer: %02X frm:%d", mixer_val, frame);
            cpc_text_print_at(0, 7, buf);
        }
    }
}
