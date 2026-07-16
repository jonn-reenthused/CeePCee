/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"
#include "furelise.h"
#include "cpc_text.h"

/* Debug version - prints mixer shadow to screen */

extern uint8_t __psg_mixer_shadow;  /* defined in cpc_sound.s */

void main(void) {
    char buf[32];
    
    cpc_init(CPC_MODE_0);
    cpc_text_init();

    /* Print initial mixer shadow */
    sprintf(buf, "Mixer: %02X", __psg_mixer_shadow);
    cpc_text_print_at(0, 0, buf);
    
    /* Print step 0 data */
    sprintf(buf, "P0: %d V0: %d", FURELIS3_periods[0], FURELIS3_volumes[0]);
    cpc_text_print_at(0, 2, buf);
    sprintf(buf, "P1: %d V1: %d", FURELIS3_periods[1], FURELIS3_volumes[1]);
    cpc_text_print_at(0, 3, buf);
    sprintf(buf, "P2: %d V2: %d", FURELIS3_periods[2], FURELIS3_volumes[2]);
    cpc_text_print_at(0, 4, buf);

    cpc_music_set_tempo(FURELIS3_TEMPO);
    cpc_music_play(FURELIS3_periods, FURELIS3_volumes, FURELIS3_STEPS);

    while (1) {
        cpc_vblank_wait();  /* music tick is handled inside vblank wait */

        /* Update mixer display each frame */
        sprintf(buf, "Mixer: %02X Step: %d", __psg_mixer_shadow, 
                (unsigned char)(__psg_mixer_shadow)); /* placeholder */
        cpc_text_print_at(0, 6, buf);
    }
}
