/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"

/* Test: 3 channels with clearly different notes
 * Channel A: C4 (low)
 * Channel B: E4 (mid) 
 * Channel C: A4 (high)
 * All playing simultaneously
 */

static const uint16_t test_periods[] = {
    /* step 0: all 3 channels play together */
    NOTE_C4, NOTE_E4, NOTE_A4,
    NOTE_C4, NOTE_E4, NOTE_A4,
    NOTE_C4, NOTE_E4, NOTE_A4,
    NOTE_C4, NOTE_E4, NOTE_A4,
    /* step 4: silence */
    0, 0, 0,
    0, 0, 0
};

static const uint8_t test_volumes[] = {
    15, 15, 15,
    15, 15, 15,
    15, 15, 15,
    15, 15, 15,
    0, 0, 0,
    0, 0, 0
};

void main(void) {
    cpc_init(CPC_MODE_0);
    
    /* Should hear a chord: C major (C4+E4+A4) */
    cpc_music_set_tempo(12);  /* slow tempo */
    cpc_music_play(test_periods, test_volumes, 6);

    while (1) {
        cpc_vblank_wait();  /* music tick is handled inside vblank wait */
    }
}
